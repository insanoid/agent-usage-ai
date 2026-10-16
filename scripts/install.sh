#!/usr/bin/env bash
# One command on a fresh Mac: check the tools, work out signing, build,
# install to ~/Applications and start Agent Usage.
#
#   git clone https://github.com/insanoid/agent-usage-ai && cd agent-usage-ai && ./scripts/install.sh
#
# Overrides: AGENT_USAGE_TEAM (signing team ID, empty for no widget) and
# AGENT_USAGE_BUNDLE_PREFIX (reverse-DNS prefix, e.g. com.yourname).
set -euo pipefail
cd "$(dirname "$0")/.."

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }
fail() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# The team ID of the first "Apple Development" certificate in the keychain:
# the certificate's organizational unit. Empty when there is none.
team_from_keychain() {
  local hash
  hash=$(security find-identity -v -p codesigning 2>/dev/null | awk '/Apple Development/ {print $2; exit}')
  [[ -n "$hash" ]] || return 0
  security find-certificate -a -Z -p 2>/dev/null \
    | awk -v h="$hash" '/SHA-1 hash:/ {p = ($3 == h)} p' \
    | sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' \
    | openssl x509 -noout -subject -nameopt multiline 2>/dev/null \
    | awk -F' = ' '/organizationalUnitName/ {print $2; exit}'
}

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
if [[ -z "${AGENT_USAGE_TEAM+set}" ]]; then
  AGENT_USAGE_TEAM=$(team_from_keychain)
fi
if [[ -n "$AGENT_USAGE_TEAM" ]]; then
  echo "    signing team: $AGENT_USAGE_TEAM"
else
  cat <<'NOTE'
    No Apple Development certificate found, so the widget is left out; the
    menu bar app works without it. To get the widget: open Xcode, Settings,
    Accounts, add your Apple ID (a free one works), then run this again.
NOTE
fi
if [[ -z "${AGENT_USAGE_BUNDLE_PREFIX:-}" ]]; then
  if [[ "$AGENT_USAGE_TEAM" == "UYGU8PDBPS" ]]; then
    AGENT_USAGE_BUNDLE_PREFIX="com.karthikeyaudupa"
  else
    # Bundle IDs belong to one team, so a builder needs their own prefix.
    AGENT_USAGE_BUNDLE_PREFIX="com.$(id -un | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')"
  fi
fi
echo "    bundle ID: $AGENT_USAGE_BUNDLE_PREFIX.agent-usage"
export AGENT_USAGE_TEAM AGENT_USAGE_BUNDLE_PREFIX

say "Building (the first build takes a few minutes)"
./scripts/build-app.sh --install

cat <<'DONE'

Agent Usage is running: look for the robot in the menu bar.
  - Click it, then the gear, to add subscriptions and log in.
  - Turn on "Open at login" in the panel footer.
  - Widget: Notification Center (or right-click the desktop) > Edit Widgets
    > Agent Usage. Edit the widget to choose which profiles it shows.
DONE
