# Private iPhone app and usage API

Status: approved by the user on 2026-11-03. Implementation in progress.

## Intent and agreed scope

Show the Hetzner machine's Claude Code and Codex subscription usage on Karthik's own iPhone. Provide a small native app and Home Screen widgets. Install through Xcode. Preserve the current Mac app, Linux terminal command, and Hermes MCP integration.

The first version covers Hetzner subscriptions only. It does not aggregate other machines, manage logins, switch accounts, redeem resets, send notifications, or distribute through TestFlight or the App Store.

## Approaches

The recommended approach is a native SwiftUI app and WidgetKit extension, backed by a private JSON API on Hetzner. This supports real Home Screen widgets and uses the existing report schema. The user selected installation on their own iPhone after this approach was proposed.

A web dashboard is simpler to distribute but does not provide the requested native widgets. Expanding the Mac app's existing project would couple its signing and platform dependencies to this work. Instead, add an independent iOS project and keep the existing Mac project and package unchanged.

## Existing system and deployment constraints

The Python package already supplies the collector and a process-local cache through `UsageService`. Reports contain version, generation time, accounts, and provider ordering. Provider errors appear as notes rather than zero usage.

Hetzner already has Tailscale HTTPS enabled. The host is `karthik-hetzner.tail9bd7eb.ts.net`. Its default HTTPS root and several alternate ports already serve applications. Preserve the complete Serve configuration and add an isolated `/agent-usage` path; verify routing and inspect the before/after configuration. Do not reset Serve or replace an existing route.

An iOS peer is connected to the tailnet. This confirms a possible network path, not yet a successful fetch from the future app. The personal Claude profile currently reports no access token; show this error faithfully.

## Server

Add an HTTP mode to the Linux package, using the existing collector. Bind only to localhost and reverse proxy through Tailscale Serve. Run it as a dedicated user systemd service with restart-on-failure and bounded logs. Choose a free local port during implementation.

Expose `GET /v1/usage` and a minimal health endpoint beneath the external `/agent-usage` route. The usage response preserves the existing version-1 report schema. Include collection age and overall collector status as compatible additional fields or headers. Do not return paths, credential material, raw exceptions, or authentication data.

Collect on startup and every five minutes. Maintain an atomic, permission-restricted disk snapshot so a service restart does not discard the previous report. HTTP reads return the snapshot immediately and do not start provider requests. Serialize collections; never start an overlapping collection. There is no remote force-refresh endpoint in v1. Refresh in the phone app means retrieving the latest server snapshot.

Before the first successful collection, return a clear unavailable response. Retain the prior report on a whole-collection failure and expose its original timestamp plus stale status. Preserve individual provider errors without substituting old successful values for them. Mark the report stale after ten minutes without a completed collection.

Require a dedicated API bearer token in addition to tailnet access. Store the server secret outside source control in a permission-restricted file. Use the private secret workflow for provisioning; do not place the token in URLs, command histories, screenshots, logs, or checked-in files. Verify token comparisons and redact authentication headers. This avoids granting every device with access to an existing shared HTTPS port access to usage data. Never enable Funnel.

## iPhone app and widget

Use SwiftUI and WidgetKit, with an independent XcodeGen project under `iOS/`. Propose iOS 17 as the minimum. Use the product's existing system fonts, usage bars, provider grouping, and status colours. Do not apply the browser artifact design system to native UI.

Create a narrowly scoped iOS model/network layer. Reuse compatible existing report-model sources through explicit source inclusion where practical, without compiling macOS process execution code or modifying the Mac package. Keep network and persistence abstractions testable.

The app provides server URL and token setup, connection testing, a grouped usage list, provider errors, last collection time, and pull-to-refresh. Store the token in Keychain. Validate HTTPS URLs and do not forward credentials across redirects or to a changed host. Clear the previous server's cached report when the configured server changes.

Use a dedicated iOS App Group for settings and the cached report. Enable a shared Keychain access group for the app and extension. Validate signing support with the selected Xcode team before promising installation on the physical device. Existing Mac App Group identifiers remain unchanged.

Both the app and the widget can fetch the API. Write shared reports atomically. Widget requests have short timeouts and retain cached data on failure. Display an offline or stale indicator with the last successful collection time. Never render a failed request as zero usage.

Provide small and medium Home Screen widgets. The small widget shows one selected provider/profile. The medium widget shows up to two selected profiles, clearly labelled. Each shows account-wide session and weekly usage where available and reset countdowns. Detailed model limits and extra spending remain in the app. Tapping a widget opens its profile in the app.

Request widget refresh around every 30 minutes; iOS decides the actual schedule. Refresh widget timelines after successful foreground app fetches. Render reset countdowns locally without pretending that a reset establishes a newly fetched usage value. Show setup instructions when unconfigured and an explicit empty state for a deleted profile.

## Verification and delivery

Test API authentication, schema compatibility, empty startup state, stale snapshots, provider errors, collection serialization, and persistence across restarts. Re-run the existing Python suite. Test Swift decoding, cache behavior, endpoint changes, authentication handling, and offline behavior. Avoid UI tests that merely duplicate view structure.

Build the app and extension for Simulator and inspect both widget sizes with fixture reports. Use the device tools for simulator interaction. Verify success, loading, missing login, offline, stale, and large-text states. Verify live API reachability from a tailnet client and unauthenticated rejection. Confirm existing Tailscale routes and Hermes tools still work.

Physical installation requires the iPhone to be available to Xcode with suitable signing and Developer Mode. Report simulator verification separately from actual phone verification. Document Xcode installation, server updates, rollback, and recovery from expired provider credentials.

## Builder decisions

The builder can choose the local port, HTTP framework, networking abstractions, filenames, and layout details within this scope. Keep the API service isolated from Hermes and the Mac app. Do not change shared tailnet policy beyond this service or restart unrelated processes. No new commit or push is assumed from this design approval.

## References

- Tailscale Serve: https://tailscale.com/docs/features/tailscale-serve
- Widget refresh policy: https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date
- Apple signing capabilities: https://developer.apple.com/documentation/xcode/adding-capabilities-to-your-app

## Native visual refinement (2026-11-03)

User selected the compact native direction after seeing v1 on their phone. Keep two balanced account panels, system text, rounded usage numerals, restrained colour, and compact reset labels. The current app-sized rows overflow the fixed widget height; widget rows must have their own vertical budget. Preserve selected accounts and show missing-login states explicitly. Keep system light/dark materials, readable contrast, and adaptive app text. No additional fonts, dependencies, backend changes, or Mac changes.

Alternative considered: a denser table. The user selected native panels because they keep account identities distinct and suit the Home Screen. Layout details remain implementation decisions.

## Match the Mac structure (2026-11-03, build 3)

User requests hiding disabled extra-usage messages, removing profile separators, and matching the Mac app's type and spacing. The iOS targets now include the existing platform-independent Typography.swift without modifying Mac sources. Widget headings and values use those tokens; app text uses the same SF Pro/SF Mono hierarchy with Dynamic Type. Normal app limits use aligned label/bar/value/reset columns, with stacked rows at accessibility sizes. Enabled spend follows the Mac's narrow currency symbol and whole-unit format. Disabled spend renders nothing. Provider profiles share one list container, avoiding system-drawn row boundaries; whitespace separates profiles.

## Reset credits and footer (2026-11-03, build 4)

User requests Codex reset counts and one centred, unboxed collection timestamp beneath the profiles. Decode the existing API reset_credits and reset_credits_expire_at fields, preserve them in the cache, and show positive available counts with expiry. Normal app chrome has only “Collected at” plus the server-generated timestamp; remove cadence and pull-to-refresh explanations. Keep automatic foreground refresh and necessary setup/error states.

## Provider branding (2026-11-03, build 5)

User requests removing the oversized application title and adding provider branding. Use the existing Mac provider artwork unchanged: Claude's orange mark and the OpenAI mark for Codex. Render the Codex mark as a template for light/dark contrast. Keep compact navigation with Settings, provider labels beside scalable marks, and the single collection footer.

## Widget link highlight fix (2026-11-03, build 6)

Widget links navigate to the requested profile without applying a selection background. Handle each URL directly through ScrollViewReader, removing persistent selection state and allowing repeated links to the same profile to request scrolling again.
