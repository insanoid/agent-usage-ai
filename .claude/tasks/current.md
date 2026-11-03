# iPhone and private API implementation plan

> Use superpowers:subagent-driven-development for the independent iOS task and direct execution for API/deployment. User approved implementation on 2026-11-03. No further plan approval is needed; no commits or pushes are authorized.

Goal: private cached usage API on Hetzner and native iPhone app/widgets.
Architecture: Python snapshot service behind Tailscale Serve; independent iOS SwiftUI/WidgetKit project.
Spec: ../context/ios-tailscale-design.md

## Constraints
- Keep Mac sources, package, build and widget behavior unchanged.
- Preserve Hermes MCP, all existing Serve routes, and account credentials.
- iOS 17+, small and medium widgets; Python 3.10+.
- Collect every 300 seconds; stale after 600 seconds; no HTTP-triggered collection.
- Bearer token from private secret workflow, localhost listener only.

## Tasks
- [x] API: tests in Tests/LinuxTests/test_api.py first; implement snapshot.py and api.py, CLI --http --token-file --snapshot --port. Verify authentication, 503 before snapshot, stale retained snapshot, restart persistence, errors, concurrent reads, and no read-triggered provider calls. Use Starlette and uvicorn already required by MCP but declare them directly.
- [x] iOS: independent iOS/project.yml, app, widget, shared networking/cache/keychain and tests. URL points to https://host/agent-usage; append /v1/usage. Report response preserves version 1 and adds collection {age_seconds, stale, status}; status is ok or failed. Reject redirects, use HTTPS, keep token in shared Keychain, atomic App Group cache, invalidate cache on endpoint changes. Test behavior, build app+extension.
- [x] Deploy: build a wheel, install isolated API environment on Hetzner, create user systemd unit and restricted snapshot/token paths. Add only /agent-usage Serve route. Verify authenticated/unauthenticated access, service restart, existing routes, MCP.
- [x] Validate: inspect iOS via device tools, run all meaningful tests, obtain fresh review, fix findings. Document physical-device steps and any blockers.

## Review focus
- Untrusted redirects must never receive bearer credentials (iOS network test).
- Cache from another endpoint must never show under a new endpoint (iOS cache test).
- Whole collector failure must retain last data with failed/stale status (API test).
- Concurrent startup/read must not block on provider calls or overlap collection (API test).
- Existing Serve routes must remain identical after deployment (remote JSON comparison).

## Progress
- Existing isolated worktree confirmed at t3/linux-mcp-version.
- Design approved. Distribution is direct Xcode installation on user's iPhone.

### API and deployment verification
- 2026-11-03: 74 Python tests pass after API review fixes; one lifecycle test then added and all 11 API tests pass.
- API review fixes: raw provider notes are sanitized at HTTP boundary; typed validation rejects malformed/nonfinite snapshots. Reproductions failed before fixes and pass after fixes.
- Live service: user systemd agent-usage-api, isolated release ~/.local/share/agent-usage-api/releases/20261103-v0.2.0.
- Private token received through request_secret file delivery, copied with mode 0600; no secret printed or checked in.
- API reaches HTTP 200 over HTTPS from the Mac; unauthenticated loopback returns401; service restart succeeds.
- All existing Serve config preserved by comparing parsed JSON after removing the single added /agent-usage handler. Hermes still discovers both MCP tools.
- Ruling: use sudo only for the exact Serve route command after normal invocation was denied. No operator policy or unrelated routing changes.
- Final Python verification: 75 tests pass locally and in Python 3.10 Linux container. Ruff check/format pass.
- Deployed wheel SHA256: 9e2b711a2fd618e0b84b183bb145b8ab7efe3107d2da27a478e0a3ca243d6078, matches local artifact.
- systemd active with NRestarts=0; token and snapshot permissions verified 0600.
- iOS implementer reports Simulator build success, strict SwiftLint clean, and screenshot checks of success/missing-login, offline, stale, small widget, medium widget; final checks pending.

### Final review fixes
- P1: genuine provider errors contain note without limits. Updated iOS decoder to default missing limits to [], with a true note-only fixture. Original decoder failed before the fix.
- P2: malformed settings/cache prevented recovery. SharedStore now quarantines malformed JSON with a diagnostic and treats it as absent. Two regression tests failed before the fix.
- P2: medium widget's second-column bars inherited the first profile URL. Each full profile column now has its own Link. No view-structure unit test added; verify via build and Simulator inspection.
- No deferred review findings. Physical iPhone signing/installation remains unverified because no physical device is available in device inventory.

- Production Swift decoder compiled and accepted the authenticated live Hetzner report after the note-only fix. No token or live report checked into the repository.

### Completion
- Final iOS verification: 10 Swift tests pass, strict SwiftLint clean, SwiftFormat lint clean, XcodeGen and Simulator app+extension builds succeed.
- Simulator screenshots inspected: normal usage, missing login, offline, stale, loading, settings, accessibility text, both widget content sizes. Gallery registration verified. Normal text size restored.
- Physical signing, Keychain access, and populated Home Screen widgets are NOT verified; no connected physical iPhone is available. Unsigned Simulator correctly reports unavailable App Group outside Debug fixtures.
- Installation steps are in iOS/README.md; API operations and rollback in linux/API.md.
- No Mac source, original script, Mac package/project, or Mac build script changes. No commits/pushes made for this phase.

### Physical install attempt
- Xcode/device inventory sees simulators only; no physical iPhone connected.
- Signed generic iOS build attempted with the existing repository signing-team discovery (team UYGU8PDBPS). Apple blocks provisioning with “PLA Update available”; account holder must accept the current Program License Agreement. Existing wildcard profiles lack App Groups. Re-run provisioning after agreement acceptance and phone connection.
- Build failed before installation. No app installed on a physical device.

- Follow-up install: iPhone Karthik is visible over USB, but pairing remains incomplete. `devicectl manage pair` timed out after60s. Personal team UYGU8PDBPS still returns PLA Update available. Unsigned physical-device build compiles successfully; signed installation remains blocked.

### Physical installation completed (2026-11-03)
- Personal-team agreement accepted; PLA error cleared. Xcode refreshed App Group provisioning after setting personal team and bundle prefix in the ignored generated project.
- Signed Debug device build succeeded with UYGU8PDBPS and com.karthikeyaudupa.agentusage. Both app and widget profiles contain group.com.karthikeyaudupa.agentusage.mobile and the user's iPhone UDID. Strict deep signature verification passed.
- CoreDeviceService held a stale device representation. Restarting that user process restored discovery; pairing then succeeded. Phone reports Developer Mode enabled.
- devicectl installation succeeded on iPhone Karthik (00008130-000A31163891401C), bundle com.karthikeyaudupa.agentusage.mobile.
- Token entry and populated Home Screen widget verification remain user setup steps. No token embedded in the app. No API/iOS commit or push performed.

## Compact native visual refinement

User selected and instructed proceeding with the compact native design. Execute directly in the existing worktree. No commit/push.
- [x] Reproduce overflow at the actual 344×162pt medium widget bounds, including the error+healthy pair.
- [x] Replace widget app-row reuse with a bounded header, two compact meters, and a single freshness footer. Use SF Rounded numerals, neutral labels, blue normal usage, amber/red only for high usage or errors. Preserve profile links and error semantics.
- [x] Align app typography and meters with the widget. Preserve dynamic type in the app; adapt widget detail to its finite height.
- [x] Inspect small/medium, missing-login, stale/offline, long labels, and accessibility text. Run Swift lint, existing tests, Simulator and signed device builds. Install in place on the same iPhone.

### Visual refinement verification
- Reproduced the missing-login layout at 344×162pt: the first column consumed most of the width and squeezed the second column. The previous 364×170pt preview did not match the reported widget.
- Widget-specific rows now reserve footer space and calculate equal panel widths. SF Rounded values, short reset labels, blue meters, explicit error states, and a native grouped background replace the app-row reuse. App headings and numerals match.
- Verified medium and small previews, missing login, long account labels, offline, and accessibility-large text. Verified the signed WidgetKit gallery and a populated medium Home Screen widget with fictional shared-cache data; both profile headers and the footer fit.
- All 10 Swift tests pass. SwiftFormat and strict SwiftLint pass. Simulator and signed physical-device builds succeed. Deep strict code-sign verification passes.
- Installed version 1.0 build 2 on iPhone Karthik in place. Existing bundle ID, App Group, and Keychain group preserved.
- Simulator uses fictional shared-cache data and no API token. The simulator's old unsigned dev.agentusage.mobile fixture app was removed to distinguish the signed widget in the gallery.
- No commit or push. Mac sources remain untouched.

## Mac typography and spacing refinement — build 3
- User requests disabled extra usage hidden, smaller Mac-like fonts, aligned rows, and no profile separator lines.
- Added the existing Sources/AgentUsageUI/Typography.swift to both iOS targets as a source reference. Mac files remain unchanged.
- App uses compact aligned limit columns, SF Pro labels, SF Mono values/time/money, compact plan badges, narrow currency symbols, and whole-unit spend. Accessibility sizes use stacked rows.
- Disabled spend no longer displays disabledReason. Fixture personal Codex now includes disabled spend with “Out of credits”; verified no such footer appears.
- Profiles share a single provider container because native list cells retained a visible boundary after separator hiding. Verified no profile boundary remains. Removed the widget's column divider too.
- Simulator and signed device builds succeed. All 10 core tests pass; SwiftLint and SwiftFormat clean. Visually checked app, accessibility-large, and medium widget.
- Installed version 1.0 build 3 on iPhone Karthik. No commits or pushes.

## Codex resets and collection footer — build 4
- Live private API already returns reset_credits=2 for personal and work Codex, with November 30 expiry dates. The iOS ProviderUsage model omitted both fields.
- Added optional resetCredits and resetCreditsExpireAt decoding and cache encoding. A regression test first failed because both fields disappeared; it now verifies counts 0/3 and the exact expiry through API decoding and a cache round trip. Existing missing-field fixtures remain compatible.
- Profile rows now show available free reset count and expiry, matching the Mac layout. Zero/missing counts remain hidden.
- Removed the normal top status section, duplicate date, refresh instructions, and fixture notice. The only normal footer is centred “Collected at” with the original server generatedAt date/time, outside any box. Automatic foreground fetching remains. Setup, loading, and failure messages still appear when applicable.
- All 11 Swift tests, SwiftFormat, strict SwiftLint, Simulator build, and signed device build pass. Inspected the normal screen in Simulator: reset rows visible, timestamp centred, no refresh instructions.
- Installed build 4 in place on iPhone Karthik. No commit/push; Mac sources and API deployment unchanged.

## Provider branding — build 5
- Removed the large Agent Usage navigation title and reduced the initial list margin. Settings remains in the compact navigation toolbar.
- Added Claude and Codex section headers with vector logo assets copied unchanged from the Mac resources. Claude retains #D97757; the OpenAI mark used for Codex is a template that adapts to light/dark mode. Attribution is included in the iOS app resources.
- Header text and mark scale with Dynamic Type; marks are hidden from VoiceOver to avoid repeating the provider name.
- Verified light and dark Simulator layouts, SwiftLint, SwiftFormat, and both Simulator and signed-device builds. No core behavior changed; no extra tests added. Installed build 5 on iPhone Karthik.
- No commit/push. Mac assets and source files unchanged.

## Widget link highlight fix — build 6
- The blue block was an explicit background driven by selectedProfile, which remained set after opening a widget link.
- Removed selection state and background. Each incoming profile URL now requests scrolling directly through ScrollViewReader, including repeated links to the same profile.
- Inspected the Simulator after opening the Codex work link: no blue selection block. Reopened the same link successfully.
- SwiftFormat, strict SwiftLint, Simulator build, signed-device build, and strict deep signature verification pass.
- Installed version 1.0 build 6 on iPhone Karthik and verified the installed version with devicectl. No commit/push; Mac files unchanged.
