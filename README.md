# Agent Usage

A macOS menu bar app and widget that show your **Claude Code** and **Codex**
usage limits — every subscription, side by side — and when each one resets.

<p>
  <img src="docs/images/panel.png" alt="The menu bar panel: Claude and Codex profiles with their plans, free resets, and a bar per limit" width="367">
  <img src="docs/images/widget-medium.png" alt="The medium widget: a column per provider, a bar per profile" width="365">
</p>

- **Grouped by provider, then profile.** Each profile shows its plan (Team ·
  Max 5×, Pro, Pro Lite…), any free usage-limit resets with their use-by date,
  and one row per limit — 5-hour, weekly, model-specific (Fable) — with time
  until it resets, plus extra-usage spend.
- **Widget** in small, medium and large sizes, for Notification Center or the
  desktop. Edit it to choose which profiles it shows.
- **Any number of subscriptions.** Add a Claude or Codex login by pointing at
  its folder, and sign in from the app.

## Install

You need macOS 14 or later, [Xcode](https://apps.apple.com/app/xcode/id497799835)
(open it once after installing), and [Homebrew](https://brew.sh). Then:

```sh
git clone https://github.com/insanoid/agent-usage-ai && cd agent-usage-ai && ./scripts/install.sh
```

The script checks your tools, installs `xcodegen` if needed, builds the app,
copies it to `~/Applications` and starts it. Look for the robot in the menu bar.

**The widget needs code signing.** If you have never signed into Xcode, the
script builds the menu bar app without the widget and says so. To get the
widget, open Xcode → Settings → Accounts, add your Apple ID (a free one
works), and run `./scripts/install.sh` again.

To update later: `git pull && ./scripts/install.sh`.

## Set up your subscriptions

Click the robot, then the gear. Each **subscription** is a provider and the
folder its login lives in:

| Provider | Folder | Default |
|----------|--------|---------|
| Claude Code | `CLAUDE_CONFIG_DIR` | `~/.claude` |
| Codex | `CODEX_HOME` | `~/.codex` |

Give subscriptions the same name to show them together — "Work" on Claude and
"Work" on Codex form one Work profile. **Log in** runs `claude auth login` or
`codex login` for that folder and opens your browser to sign in.

The first run starts from [`config/subscriptions.json`](config/subscriptions.json),
which doubles as a sample: four folders, no credentials.

```json
{
  "version": 1,
  "subscriptions": [
    { "name": "Work", "provider": "claude", "dir": "~/.claude-work" },
    { "name": "Personal", "provider": "claude", "dir": "~/.claude" },
    { "name": "Work", "provider": "codex", "dir": "~/.codex-work" },
    { "name": "Personal", "provider": "codex", "dir": "~/.codex" }
  ]
}
```

Your copy lives in `~/Library/Application Support/AgentUsage/subscriptions.json`;
edit it in the app or by hand.

## How it works

The app runs the bundled [`bin/agent-usage`](bin/agent-usage) script every five
minutes (and when you open the panel, if the numbers are over a minute old)
with `/usr/bin/python3`, which Xcode provides. The script reads each login's
token, asks Anthropic and OpenAI for the limits, and prints JSON. It also works
on its own in a terminal:

```sh
bin/agent-usage --config config/subscriptions.json          # a table
bin/agent-usage --config config/subscriptions.json --json   # what the app reads
```

- **Claude:** reads the OAuth token Claude Code keeps in the Keychain, then
  calls `api.anthropic.com/api/oauth/usage` and `/api/oauth/profile`. Free
  resets and plan details come from undocumented parts of that API; if they
  change, only those details disappear. The plan is cached for a day in
  `~/.cache/agent-usage/`.
- **Codex:** runs `codex app-server` per folder and asks it for the account's
  rate limits, the same numbers the Codex TUI shows.
- **Credentials are only read, never written or sent anywhere else.** An idle
  Claude login's token expires after a few hours; using Claude Code with that
  folder refreshes it.
- **The widget** is sandboxed and cannot run the script, so the app writes
  each report to a shared App Group container and reloads the widget.
- **When a read fails** (for example a rate limit), the panel keeps the
  previous numbers and marks the profile with ⚠︎; hover it for the error.

## Develop

```sh
swift test                                  # unit tests, no Xcode project needed
AGENT_USAGE_LIVE=1 swift test               # also run the real script against your logins
swiftformat Sources Tests App && swiftlint lint Sources Tests App
./scripts/build-app.sh --install            # rebuild and restart
```

| Path | What |
|------|------|
| `bin/agent-usage` | The usage script the app bundles. |
| `config/subscriptions.json` | Default and sample subscriptions. |
| `Sources/AgentUsageCore` | Report model, script runner, store, caches, subscriptions. No UI. |
| `Sources/AgentUsageUI` | Views shared by the panel and the widget: rows, bars, type and spacing, logos. |
| `App/AgentUsage` | The menu bar app and its settings window. |
| `App/AgentUsageWidget` | The WidgetKit extension. |
| `project.yml` | XcodeGen spec; the `.xcodeproj` is generated, not committed. |

`scripts/build-app.sh` takes the signing team and bundle-ID prefix from
`AGENT_USAGE_TEAM` and `AGENT_USAGE_BUNDLE_PREFIX`; `install.sh` works both out
from your Keychain. Logs: `/usr/bin/log show --last 10m --info --predicate 'subsystem == "com.karthikeyaudupa.agent-usage"'`.

Provider marks: LobeHub Icons (MIT). Robot: Lucide (ISC). See
[`Sources/AgentUsageUI/Resources/ATTRIBUTION.md`](Sources/AgentUsageUI/Resources/ATTRIBUTION.md).
