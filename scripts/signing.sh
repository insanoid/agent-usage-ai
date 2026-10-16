#!/usr/bin/env bash
# Shared by build-app.sh and install.sh: work out code signing for this Mac
# unless the environment already says. Source it; it exports:
#   AGENT_USAGE_TEAM           the first "Apple Development" certificate's team
#                              ID in the Keychain, or empty (ad-hoc, no widget)
#   AGENT_USAGE_BUNDLE_PREFIX  com.<your macOS username>

# The team ID is the certificate's organizational unit.
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

# Set but empty means "no team" on purpose, so only fill in when unset.
if [[ -z "${AGENT_USAGE_TEAM+set}" ]]; then
  AGENT_USAGE_TEAM=$(team_from_keychain)
fi
if [[ -z "${AGENT_USAGE_BUNDLE_PREFIX:-}" ]]; then
  # Bundle IDs belong to one team, so each builder needs their own prefix.
  AGENT_USAGE_BUNDLE_PREFIX="com.$(id -un | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')"
fi
export AGENT_USAGE_TEAM AGENT_USAGE_BUNDLE_PREFIX
