#!/usr/bin/env bash
# Build AgentUsage.app (menu bar app plus its widget) into build/. With
# --install, copy it to /Applications and (re)start it.
#
# Signing comes from the environment:
#   AGENT_USAGE_TEAM           Apple Development team ID. Empty builds an
#                              ad-hoc signed app without the widget, which
#                              will not load unsigned.
#   AGENT_USAGE_BUNDLE_PREFIX  reverse-DNS prefix for bundle IDs.
#   AGENT_USAGE_INSTALL_DIR    where --install puts the app; /Applications.
#   AGENT_USAGE_AUTO_INSTALL   1 to install after every team-signed build,
#                              as if --install were passed.
# Unset, the first two are worked out by scripts/signing.sh. scripts/local.env,
# if present (it is gitignored), sets any of these for this machine.
set -euo pipefail

cd "$(dirname "$0")/.."
if [[ -f scripts/local.env ]]; then
  # shellcheck disable=SC1091
  source scripts/local.env
fi
# shellcheck source=scripts/signing.sh
source scripts/signing.sh

derived="build/DerivedData"
app="$derived/Build/Products/Release/AgentUsage.app"
install_dir="${AGENT_USAGE_INSTALL_DIR:-/Applications}"
lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

xcodegen generate --quiet

if [[ -n "$AGENT_USAGE_TEAM" ]]; then
  xcodebuild -project AgentUsage.xcodeproj -scheme AgentUsage -configuration Release \
    -destination "generic/platform=macOS" -derivedDataPath "$derived" -allowProvisioningUpdates -quiet build
else
  # No team: no entitlements, no App Group, and no widget.
  xcodebuild -project AgentUsage.xcodeproj -scheme AgentUsage -configuration Release \
    -destination "generic/platform=macOS" -derivedDataPath "$derived" -quiet build \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= \
    CODE_SIGN_ENTITLEMENTS= AGENT_USAGE_APP_GROUP=
  rm -rf "$app/Contents/PlugIns/AgentUsageWidget.appex"
  codesign --force --deep --sign - "$app"
  echo "note: built without a signing team, so the widget is left out" >&2
fi
echo "built $app"

install=false
if [[ "${1:-}" == "--install" ]]; then
  install=true
elif [[ "${AGENT_USAGE_AUTO_INSTALL:-0}" == "1" && -n "$AGENT_USAGE_TEAM" ]]; then
  # Never auto-install an ad-hoc build over the real, widget-bearing one.
  install=true
fi

if [[ "$install" == true ]]; then
  installed="$install_dir/AgentUsage.app"
  pkill -x AgentUsage || true
  # `open` fails with -600 while the old instance is still shutting down.
  while pgrep -x AgentUsage >/dev/null; do sleep 0.2; done
  # One copy only: a second registered copy can win the widget gallery.
  moved=false
  for old in /Applications/AgentUsage.app "$HOME/Applications/AgentUsage.app"; do
    if [[ "$old" != "$installed" && -d "$old" ]]; then
      "$lsregister" -u "$old"
      rm -rf "$old"
      moved=true
      echo "removed the old copy at $old"
    fi
  done
  mkdir -p "$install_dir"
  rm -rf "$installed"
  cp -R "$app" "$install_dir/"
  # The build folder's copy stays on disk; take it out of LaunchServices and
  # PlugInKit so only the installed app and its widget are mapped.
  "$lsregister" -u "$app"
  if pluginkit -m -i "$AGENT_USAGE_BUNDLE_PREFIX.agent-usage.widget" | grep -q "$PWD/build/"; then
    pluginkit -r "$app/Contents/PlugIns/AgentUsageWidget.appex"
  fi
  "$lsregister" -f "$installed"
  if [[ "$moved" == true ]]; then
    # The widget daemon keeps launching the extension from the old path,
    # which no longer exists. It restarts on its own and re-reads the path.
    killall chronod 2>/dev/null || echo "chronod was not running"
  fi
  # LaunchServices can still refuse (-600) for a moment after the old process exits.
  for _ in 1 2 3 4 5; do
    open "$installed" 2>/dev/null && break
    sleep 1
  done
  pgrep -x AgentUsage >/dev/null || { echo "AgentUsage did not start" >&2; exit 1; }
  echo "installed $installed"
fi
