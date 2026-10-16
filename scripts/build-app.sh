#!/usr/bin/env bash
# Build AgentUsage.app (menu bar app plus its widget) into build/. With
# --install, copy it to ~/Applications and (re)start it.
#
# Signing comes from the environment:
#   AGENT_USAGE_TEAM           Apple Development team ID. Empty builds an
#                              ad-hoc signed app without the widget, which
#                              will not load unsigned.
#   AGENT_USAGE_BUNDLE_PREFIX  reverse-DNS prefix for bundle IDs.
# scripts/install.sh works both out for you.
set -euo pipefail

cd "$(dirname "$0")/.."
: "${AGENT_USAGE_TEAM=UYGU8PDBPS}"
: "${AGENT_USAGE_BUNDLE_PREFIX:=com.karthikeyaudupa}"
export AGENT_USAGE_TEAM AGENT_USAGE_BUNDLE_PREFIX

derived="build/DerivedData"
app="$derived/Build/Products/Release/AgentUsage.app"
install_dir="$HOME/Applications"

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

if [[ "${1:-}" == "--install" ]]; then
  pkill -x AgentUsage || true
  # `open` fails with -600 while the old instance is still shutting down.
  while pgrep -x AgentUsage >/dev/null; do sleep 0.2; done
  mkdir -p "$install_dir"
  rm -rf "$install_dir/AgentUsage.app"
  cp -R "$app" "$install_dir/"
  # LaunchServices can still refuse (-600) for a moment after the old process exits.
  for _ in 1 2 3 4 5; do
    open "$install_dir/AgentUsage.app" 2>/dev/null && break
    sleep 1
  done
  pgrep -x AgentUsage >/dev/null || { echo "AgentUsage did not start" >&2; exit 1; }
  echo "installed $install_dir/AgentUsage.app"
fi
