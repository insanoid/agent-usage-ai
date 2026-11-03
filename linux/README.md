# Agent Usage for Linux and Hermes

A terminal command and local MCP server for Claude Code and Codex subscriptions.
The Python package bundles the existing usage collector unchanged. The Mac app,
widget, build scripts, and original `bin/agent-usage` command are unaffected.

## Install

Requires Python 3.10 or later, uv, and the provider CLIs for your subscriptions.
Run in this repository on each Linux machine:

```sh
uv tool install .
mkdir -p ~/.config/agent-usage
cp config/subscriptions.json ~/.config/agent-usage/subscriptions.json
```

Edit the copied file to match the subscriptions on that machine. Remove entries
you do not use. Use absolute paths or `~/` paths. Each subscription needs an
existing login. Claude reads `<dir>/.credentials.json` on Linux. Codex must be
on PATH and reads its configured home through `codex app-server`.

```json
{
  "version": 1,
  "subscriptions": [
    {"name": "Personal", "provider": "claude", "dir": "~/.claude"},
    {"name": "Personal", "provider": "codex", "dir": "~/.codex"}
  ]
}
```

The default configuration is `$XDG_CONFIG_HOME/agent-usage/subscriptions.json`,
or `~/.config/agent-usage/subscriptions.json`. Pass `--config /absolute/path.json`
to use another file. No dependency on `cc-conf` or account-management shell functions.

```sh
agent-usage
agent-usage --json
agent-usage --config ~/.config/agent-usage/subscriptions.json --json
```

The table shows session and weekly limits. JSON includes all reported limits,
plans, reset times, and extra usage. Percentages represent usage consumed.
Provider failures appear as notes, not zero usage. Expired Claude tokens require
opening Claude Code with the corresponding subscription; this tool does not refresh them.
`--free-resets` (or `AGENT_USAGE_FREE_RESETS=1`) opts into the existing undocumented
Claude free-reset lookup, which identifies the request as Claude Code.

## Connect Hermes on the same machine

Find the installed executable with `command -v agent-usage`. Merge the following
into `~/.hermes/config.yaml`, replacing both paths with your actual absolute paths:

```yaml
mcp_servers:
  agent_usage:
    command: /home/YOUR_USER/.local/bin/agent-usage
    args: ["--mcp", "--config", "/home/YOUR_USER/.config/agent-usage/subscriptions.json"]
    timeout: 90
```

Restart Hermes. Ask: “Check my subscription usage and tell me which accounts have
headroom.” Hermes starts and stops the MCP process. No daemon, port, or HTTP
service is needed. Ensure Hermes inherits a PATH containing `codex`.

Tools:

- `list_subscriptions`: configured names, stable slots, and providers, without paths or credentials.
- `get_usage(refresh=false)`: a complete report, cached in memory for 60 seconds.
  `refresh=true` fetches again. Configuration changes invalidate the cache.

The server exposes only configured subscriptions. Tools cannot choose arbitrary
credential paths or change configuration. Reports contain usage data, not tokens.
Provider requests still contact Anthropic and OpenAI, as the Mac collector does.
Configuration errors stop startup with a message on stderr. stdout is reserved for MCP.

Hermes configuration follows the [official MCP documentation](https://github.com/NousResearch/hermes-agent/blob/main/website/docs/user-guide/features/mcp.md).
The server uses the [official Python MCP SDK](https://github.com/modelcontextprotocol/python-sdk).

## Develop

```sh
uv sync --group dev
uv run pytest Tests/ScriptTests Tests/LinuxTests
uv run ruff check linux/agent_usage Tests/LinuxTests
uv build
```

To update an installed copy after pulling repository changes, run `uv tool install --force .`.

## Private iPhone API

The optional HTTP mode supplies cached usage to the iPhone app over Tailscale.
See [API deployment and rollback](API.md). It runs in a separate service and does
not replace the Hermes MCP integration.
