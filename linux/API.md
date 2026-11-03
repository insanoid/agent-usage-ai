# Private usage API

`agent-usage --http --token-file /private/path` runs a loopback-only server on
port 9135. Pass `--port` to choose another port and `--snapshot` to choose the
durable snapshot file. Existing CLI and MCP commands retain their behavior.

Requests require `Authorization: Bearer <token>`. Use a random token of at least
32 ASCII characters, stored in a mode-0600 file. Never put it in a URL or source
control. The phone stores the same token in Keychain.

- `GET /v1/usage`: the version-1 report with `collection.age_seconds`,
  `collection.stale`, and `collection.status` (`ok` or `failed`).
- `GET /health`: authenticated readiness check.
- HTTP 401: missing or incorrect token; HTTP 503: no snapshot is available yet.

The collector runs on startup and every five minutes. Requests read the snapshot
and never trigger a provider request. A failed whole collection retains the
previous report and marks status `failed`. Individual provider failures remain
provider notes. Reports older than ten minutes are stale. Server snapshots
survive restarts, and HTTP responses use `Cache-Control: no-store`.

## Hetzner deployment

The API runs independently of the installed Hermes CLI package:

- Unit: `~/.config/systemd/user/agent-usage-api.service` (template in `systemd/`).
- Runtime: `~/.local/share/agent-usage-api/current`, a symlink to a release environment.
- Config: `~/.config/agent-usage/subscriptions.json`.
- Token: `~/.config/agent-usage/api-token`, mode 0600.
- Snapshot: `~/.local/state/agent-usage/snapshot.json`, mode 0600.
- URL: `https://karthik-hetzner.tail9bd7eb.ts.net/agent-usage`.

Install a built wheel into a new release environment with `uv venv` and `uv pip
install --python <release>/bin/python <wheel>`. Point `current` at that release
atomically, then run `systemctl --user restart agent-usage-api`. Keep the previous
release for rollback. The service explicitly includes the provider CLI paths.

Initial installation also requires copying the service template, installing the
private token, and running:

```sh
systemctl --user daemon-reload
systemctl --user enable --now agent-usage-api
sudo tailscale serve --bg --https=443 --set-path=/agent-usage http://127.0.0.1:9135
```

Back up `tailscale serve status --json` before changing routing. Preserve every
existing handler and port. The API route is private to the tailnet; do not enable
Funnel. A token is still required from authorized tailnet clients.

For rollback, restore the previous `current` symlink and restart the service.
To remove only this API route, run:

```sh
sudo tailscale serve --https=443 --set-path=/agent-usage off
systemctl --user disable --now agent-usage-api
```

Do not use `tailscale serve reset`, which would remove unrelated applications.
Logs: `journalctl --user -u agent-usage-api`. Access logs are disabled; collection
errors log exception types only. Provider login recovery stays in the provider's
CLI. The API never offers a login or token-refresh endpoint.

For iPhone setup and signing, see `../iOS/README.md`.
