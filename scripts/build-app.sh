#!/usr/bin/env bash
# Build AgentUsage.app (menu bar app plus its widget) into build/. With
# --install, copy it to ~/Applications and (re)start it.
#
# Signs with the personal Apple Development team set in project.yml; the
# widget will not load unsigned.
set -euo pipefail

cd "$(dirname "$0")/.."
derived="build/DerivedData"
app="$derived/Build/Products/Release/AgentUsage.app"
install_dir="$HOME/Applications"

xcodegen generate --quiet
xcodebuild -project AgentUsage.xcodeproj -scheme AgentUsage -configuration Release \
  -derivedDataPath "$derived" -allowProvisioningUpdates -quiet build
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
