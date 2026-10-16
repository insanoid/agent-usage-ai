#!/usr/bin/env bash
# One command on a fresh Mac: check the tools, work out signing, build,
# install to /Applications and start Agent Usage.
#
#   git clone https://github.com/insanoid/agent-usage-ai && cd agent-usage-ai && ./scripts/install.sh
#
# Overrides: AGENT_USAGE_TEAM (signing team ID, empty for no widget) and
# AGENT_USAGE_BUNDLE_PREFIX (reverse-DNS prefix, e.g. com.yourname).
set -euo pipefail
cd "$(dirname "$0")/.."

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }
fail() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

say "Checking tools"
xcodebuild -version >/dev/null 2>&1 \
  || fail "Xcode is required (the full app, not only the Command Line Tools). Install it from the App Store, open it once, then run: sudo xcode-select -s /Applications/Xcode.app"
/usr/bin/python3 -c 'import sys; sys.exit(sys.version_info < (3, 9))' 2>/dev/null \
  || fail "/usr/bin/python3 3.9 or newer is required; it comes with Xcode"
for cli in claude codex; do
  command -v "$cli" >/dev/null || printf '    note: %s is not on PATH; install it to log in to %s subscriptions\n' "$cli" "$cli"
done
if ! command -v xcodegen >/dev/null; then
  command -v brew >/dev/null || fail "xcodegen is required. Install Homebrew (https://brew.sh), then run this again"
  say "Installing xcodegen with Homebrew"
  brew install xcodegen
fi

say "Working out code signing"
# shellcheck source=scripts/signing.sh
source scripts/signing.sh
if [[ -n "$AGENT_USAGE_TEAM" ]]; then
  echo "    signing team: $AGENT_USAGE_TEAM"
else
  cat <<'NOTE'
    No Apple Development certificate found, so the widget is left out; the
    menu bar app works without it. To get the widget: open Xcode, Settings,
    Accounts, add your Apple ID (a free one works), then run this again.
NOTE
fi
echo "    bundle ID: $AGENT_USAGE_BUNDLE_PREFIX.agent-usage"

say "Building (the first build takes a few minutes)"
./scripts/build-app.sh --install

cat <<'DONE'

Agent Usage is running: look for the robot in the menu bar.
  - Click it, then the gear, to add subscriptions and log in.
  - Turn on "Open at login" in the panel footer.
  - Widget: Notification Center (or right-click the desktop) > Edit Widgets
    > Agent Usage. Edit the widget to choose which profiles it shows.
DONE
