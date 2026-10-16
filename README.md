# AgentUsage

A macOS menu bar app and widget that show Claude Code and Codex usage for every
configured account, and when each limit resets.

- **Menu bar:** a gauge whose needle follows the most-used account-wide limit.
  Click it for the panel: grouped by provider (Claude, Codex), then by profile.
  Each profile shows its plan, any free usage-limit resets with their use-by
  date, and one row per limit — label, bar, percent, time until reset — plus
  extra-usage spend.
- **Widget:** small (the profile closest to a limit), medium (one line per
  profile) and large (the panel layout), for Notification Center or the desktop.
- **New profiles appear on their own.** Every refresh re-reads
  `~/.config/claude-accounts/accounts.conf`; a new `account = …` line shows up
  within five minutes, or as soon as the panel opens.

## How it gets the numbers

The app runs `~/.agents/bin/agent-usage --json` every five minutes, and again
when the panel opens if the data is more than a minute old. That script owns the
Keychain, HTTP and Codex app-server calls, so the CLI table and this app always
agree.

The widget is sandboxed and cannot run the script. After each refresh the app
writes the report to the App Group container
`~/Library/Group Containers/UYGU8PDBPS.com.karthikeyaudupa.agent-usage/report.json`
and asks WidgetKit to reload. The widget therefore updates only while the app
runs, and flags data older than 30 minutes.

To use a script elsewhere:

```sh
defaults write com.karthikeyaudupa.agent-usage scriptPath /path/to/agent-usage
```

Claude's free resets ("grants") and plan come from undocumented parts of the
API: the usage call adds `?cedar_ember=1` and identifies as the installed
Claude Code (`User-Agent: claude-cli/<version> (external, cli)`), and the plan
comes from `/api/oauth/profile`, cached for a day in `~/.cache/agent-usage/`.
If either stops working, only that detail disappears. When a read fails (for
example HTTP 429), the app keeps the previous numbers and says so.

An idle Claude profile's access token expires, and that account then shows
"token stale — run: cc <slot>". Running Claude Code on that profile refreshes it.

## Layout

| Path | What |
|------|------|
| `Sources/AgentUsageCore` | Report model, script runner, store, widget cache. No UI. |
| `Sources/AgentUsageUI` | Views shared by the panel and the widget: rows, bars, type and spacing tokens, provider logos. |
| `App/AgentUsage` | The menu bar app. |
| `App/AgentUsageWidget` | The WidgetKit extension. |
| `project.yml` | XcodeGen spec; the `.xcodeproj` is generated and not committed. |

## Build and install

Requires macOS 14, Xcode, and `xcodegen` (`brew install xcodegen`). Signing uses
the personal Apple Development team (`UYGU8PDBPS`); the widget does not load
unsigned.

```sh
./scripts/build-app.sh            # build into build/DerivedData
./scripts/build-app.sh --install  # copy to ~/Applications and start it
```

Then turn on "Open at login" in the panel footer, and add the widget from
Notification Center's "Edit Widgets" or the desktop's context menu.

## Develop

```sh
swift test                         # Core tests, no Xcode project needed
AGENT_USAGE_LIVE=1 swift test      # also decode the real script's output
swiftformat Sources Tests App && swiftlint lint Sources Tests App
```

Refresh and widget results go to the unified log:

```sh
/usr/bin/log show --last 10m --info --predicate 'subsystem == "com.karthikeyaudupa.agent-usage"'
```
