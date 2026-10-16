#!/usr/bin/env bash
# Regenerate the README screenshots in docs/images from the real views and the
# app's last cached report. Run the app once first so the report exists.
set -euo pipefail
cd "$(dirname "$0")/.."
root=$PWD

shopt -s nullglob
reports=("$HOME"/Library/Group\ Containers/*.agent-usage/report.json)
report=${reports[0]:-}
[[ -n "$report" ]] || { echo "error: no cached report; run Agent Usage first" >&2; exit 1; }

# A throwaway package: the harness plus links to the app's view files, which
# live in the Xcode targets rather than in a library.
work="build/screenshots"
mkdir -p "$work/Sources/Screenshots"
rm -f "$work/Sources/Screenshots/"*.swift
ln -sf "$root/scripts/screenshots/main.swift" "$work/Sources/Screenshots/"
for view in UsagePanel PanelFooter SettingsView SubscriptionsModel LaunchAtLoginRow \
  ExtraUsageAlertRow AlertPreferences StatusItemMenu; do
  ln -sf "$root/App/AgentUsage/$view.swift" "$work/Sources/Screenshots/"
done
ln -sf "$root/App/AgentUsageWidget/UsageWidgetView.swift" "$work/Sources/Screenshots/"
cat > "$work/Package.swift" <<PACKAGE
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "Screenshots",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "$root")],
    targets: [.executableTarget(name: "Screenshots", dependencies: [
        .product(name: "AgentUsageCore", package: "$(basename "$root")"),
        .product(name: "AgentUsageUI", package: "$(basename "$root")"),
    ])]
)
PACKAGE

swift run --package-path "$work" Screenshots "$report" "$root/config/subscriptions.json" "$root/docs/images"
