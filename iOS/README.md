# Agent Usage for iPhone

This independent iOS 17+ app reads the private Hetzner usage API. It does not run collectors, switch accounts, or alter the Mac app. The native app shows all limits and spending. Small and medium Home Screen widgets show account-wide session and weekly limits.

## Build and test

Install Xcode and XcodeGen, then run from the repository root:

```sh
swift test --package-path iOS
xcodegen generate --spec iOS/project.yml
xcodebuild -project iOS/AgentUsageMobile.xcodeproj \
  -scheme AgentUsageMobile -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath iOS/build CODE_SIGNING_ALLOWED=NO build
open iOS/AgentUsageMobile.xcodeproj
```

XcodeGen generates the project and the Info.plist/entitlement files. The project is intentionally separate from the Mac project and root Swift package. The lean model supports the same version-1 report schema plus required API collection metadata.

## Install on your iPhone

1. Connect the iPhone to Xcode. Enable Developer Mode on the iPhone when prompted.
2. Open `iOS/AgentUsageMobile.xcodeproj`. Select the `AgentUsageMobile` scheme.
3. In project build settings, set `USAGE_BUNDLE_PREFIX` to a reverse-DNS prefix you control. Select the same development team for both targets.
4. Keep automatic signing enabled. Confirm both targets have the same App Group and shared Keychain group. The defaults derive from the bundle prefix: `group.<prefix>.mobile` and `<AppIdentifierPrefix><prefix>.mobile.shared`.
5. Register or select that App Group for both targets in Signing & Capabilities. Resolve provisioning errors before running. App Group support depends on the selected team; Simulator success does not verify physical-device signing.
6. Select the connected iPhone and Run. Trust the developer profile if iOS requests it.
7. Connect the iPhone to the same Tailscale network. Open Agent Usage → Settings. Use `https://karthik-hetzner.tail9bd7eb.ts.net/agent-usage` and enter the dedicated API bearer token supplied through the private prompt. Never paste the token into a terminal command or source file.
8. Select **Save and test connection**. Add Agent Usage from the Home Screen widget gallery. Edit each widget to select profiles.

No signing team or credential is embedded. Physical installation and shared Keychain access require validation on the actual device. Development provisioning can expire; rebuild from Xcode when required.

## Refresh and failure behavior

The server collects every five minutes. Pull-to-refresh retrieves the server snapshot; it does not trigger collection. The widget requests a timeline update after approximately 30 minutes, subject to iOS scheduling. Open the app when you need a current snapshot.

Reports older than ten minutes, explicit server stale reports, and failed collections show a stale indicator. Network failures preserve the prior report and show an offline indicator. All states retain the original collection timestamp. Reset countdowns are local timers; passing a reset never invents a new usage value. Missing provider logins show the server's error instead of zero usage. Reauthenticate that provider on Hetzner, then wait for collection and refresh the app.

Server URLs must use HTTPS. Credentials in URLs, queries and fragments are rejected. All redirects are rejected, including redirects to the same host. Tokens are scoped to their exact configured base URL in a shared Keychain group. Blank token input keeps the token already saved for that URL. A new URL requires its own token. Changing the URL clears the shared cache. In-flight responses from a previous URL cannot replace the new server's cache.

Cache/settings files live only in the dedicated iOS App Group. Cross-process file locks serialize changes; atomic writes avoid partial reports. Tokens use `AfterFirstUnlockThisDeviceOnly`; the widget cannot access them before the first device unlock following a restart. Cache files use matching first-unlock protection. Sensitive responses are not saved by URLSession.

## Simulator inspection

Debug builds support fictional fixtures without credentials. In Xcode's scheme arguments, add:

```text
-usage-fixture success
```

Replace `success` with `offline`, `stale`, `missing-login`, `long-labels`, or `loading` to inspect those states. The success fixture includes a missing-login provider. Add `-widget-preview small` or `-widget-preview medium` to inspect compact widget content at 344×162pt (medium) or 158×162pt (small). The missing-login fixture pairs an unavailable account with a healthy account. Widget text uses a fixed compact type scale; the app supports Dynamic Type, and widget VoiceOver labels retain full values and reset dates. These arguments are ignored in Release builds. Widget content previews are an app harness; also inspect the actual WidgetKit gallery/configuration and Home Screen placement before physical delivery.

Use the device tool to open the Simulator and its returned pinned `agent-device` command for launches, taps, settings and screenshots. Example launch arguments:

```text
open dev.agentusage.mobile --relaunch --launch-args=-usage-fixture --launch-args=success
open dev.agentusage.mobile --relaunch --launch-args=-usage-fixture --launch-args=success --launch-args=-widget-preview --launch-args=medium
```

Disable fixture arguments to check the unconfigured setup screen. Inspect normal and accessibility text sizes, then restore the default text size.
