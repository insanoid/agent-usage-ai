#!/usr/bin/env bash
# Regenerate the README screenshots in docs/images from the real views.
#
# By default they show UsageReport.sample(): made-up numbers, safe to publish.
# --live uses the app's last cached report instead — your real usage, plans
# and spend — for checking a change locally; do not commit those images.
set -euo pipefail
cd "$(dirname "$0")/.."
root=$PWD

report="--sample"
if [[ "${1:-}" == "--live" ]]; then
  shopt -s nullglob
  reports=("$HOME"/Library/Group\ Containers/*.agent-usage/report.json)
  report=${reports[0]:-}
  [[ -n "$report" ]] || { echo "error: no cached report; run Agent Usage first" >&2; exit 1; }
fi

# A throwaway package: the harness plus links to the app's view files, which
# live in the Xcode targets rather than in a library.
work="build/screenshots"
mkdir -p "$work/Sources/Screenshots"
rm -f "$work/Sources/Screenshots/"*.swift
ln -sf "$root/scripts/screenshots/main.swift" "$work/Sources/Screenshots/"
for source in "$root"/App/AgentUsage/*.swift; do
  # The app's @main entry point would clash with the harness's own.
  [[ "$(basename "$source")" == "AgentUsageApp.swift" ]] && continue
  ln -sf "$source" "$work/Sources/Screenshots/"
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
