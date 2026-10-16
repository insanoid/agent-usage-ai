#!/usr/bin/env bash
# Build AgentUsage.app and zip it into dist/ for download, with a SHA-256.
#
# AGENT_USAGE_TEAM set (the default on this Mac): signed with that team, widget
# included. AGENT_USAGE_TEAM="" (what CI uses): ad-hoc signed, no widget.
# Neither is notarized, so a downloaded copy needs "Open Anyway" once.
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build-app.sh
app="build/DerivedData/Build/Products/Release/AgentUsage.app"
version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$app/Contents/Info.plist")
if [[ -d "$app/Contents/PlugIns/AgentUsageWidget.appex" ]]; then
  flavour=""
else
  flavour="-no-widget"
fi

mkdir -p dist
zip="dist/AgentUsage-$version$flavour.zip"
rm -f "$zip" "$zip.sha256"
# ditto keeps the bundle's symlinks, permissions and signature intact.
ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"
(cd dist && shasum -a 256 "$(basename "$zip")" > "$(basename "$zip").sha256")
echo "packaged $zip"
cat "$zip.sha256"
