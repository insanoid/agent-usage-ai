"""Linux configuration and report behavior, without real account access."""

import json
from pathlib import Path
from typing import Any

import pytest
from agent_usage import cli
from agent_usage.backend import collector
from agent_usage.service import ConfigurationError, UsageService, default_config, read_accounts


def write_config(path: Path, name: str = "Personal") -> Path:
    path.write_text(
        json.dumps(
            {
                "version": 1,
                "subscriptions": [
                    {"name": name, "provider": "claude", "dir": str(path.parent / "claude")},
                    {"name": name, "provider": "codex", "dir": str(path.parent / "codex")},
                ],
            }
        )
    )
    return path


def test_default_config_respects_xdg(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path))
    assert default_config() == tmp_path / "agent-usage/subscriptions.json"


@pytest.mark.parametrize(
    "document",
    [
        [],
        {},
        {"version": 2, "subscriptions": []},
        {"version": 1, "subscriptions": []},
        {"version": 1, "subscriptions": [None]},
        {"version": 1, "subscriptions": [{"name": "A", "provider": "other", "dir": "/a"}]},
        {"version": 1, "subscriptions": [{"name": "A", "provider": "claude", "dir": "relative"}]},
        {"version": 1, "subscriptions": [{"name": 1, "provider": "claude", "dir": "/a"}]},
    ],
)
def test_invalid_config(tmp_path: Path, document: Any) -> None:
    config = tmp_path / "subscriptions.json"
    config.write_text(json.dumps(document))
    with pytest.raises(ConfigurationError):
        read_accounts(config)


def test_colliding_names_rejected(tmp_path: Path) -> None:
    config = tmp_path / "subscriptions.json"
    config.write_text(
        json.dumps(
            {
                "version": 1,
                "subscriptions": [
                    {"name": name, "provider": provider, "dir": "/unused"}
                    for name, provider in (("Work!", "claude"), ("Work", "codex"))
                ],
            }
        )
    )
    with pytest.raises(ConfigurationError, match="distinct"):
        read_accounts(config)


def test_cache_refresh_expiry_and_config_change(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    config = write_config(tmp_path / "subscriptions.json")
    calls = []
    now = [0.0]
    monkeypatch.setattr("agent_usage.service.time.monotonic", lambda: now[0])

    def collect(accounts: list[dict], free_resets: bool = False) -> list[dict]:
        calls.append(accounts)
        assert free_resets
        return [{"slot": accounts[0]["slot"], "claude": {"note": "token stale — run: cc personal"}}]

    monkeypatch.setattr(collector, "collect", collect)
    service = UsageService(config, free_resets=True)
    first = service.report()
    assert "cc personal" not in first["accounts"][0]["claude"]["note"]
    first["accounts"].clear()
    assert service.report()["accounts"]
    assert len(calls) == 1
    service.report(refresh=True)
    assert len(calls) == 2
    now[0] = 61
    service.report()
    assert len(calls) == 3
    write_config(config, name="Work")
    assert service.report()["accounts"][0]["slot"] == "work"
    assert len(calls) == 4


def test_subscriptions_hide_directories(tmp_path: Path) -> None:
    service = UsageService(write_config(tmp_path / "subscriptions.json"))
    assert service.subscriptions() == [
        {"slot": "personal", "name": "Personal", "providers": ["claude", "codex"]}
    ]


def test_cli_json_and_table(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: Any) -> None:
    config = write_config(tmp_path / "subscriptions.json")
    monkeypatch.setattr(
        collector,
        "collect",
        lambda *a, **k: [
            {
                "slot": "personal",
                "label": "Personal",
                "claude": {"note": "not logged in"},
                "codex": None,
            }
        ],
    )
    assert cli.main(["--config", str(config), "--json"]) == 0
    assert json.loads(capsys.readouterr().out)["accounts"][0]["claude"]["note"] == "not logged in"
    assert cli.main(["--config", str(config)]) == 0
    assert "Personal" in capsys.readouterr().out


def test_missing_config_keeps_stdout_clean(tmp_path: Path, capsys: Any) -> None:
    assert cli.main(["--config", str(tmp_path / "missing"), "--mcp"]) == 2
    captured = capsys.readouterr()
    assert captured.out == ""
    assert "Cannot read subscriptions" in captured.err


def test_linux_credential_file(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(collector.platform, "system", lambda: "Linux")
    credential = tmp_path / ".credentials.json"
    assert collector.claude_token(str(tmp_path)) == (None, "not logged in")
    credential.write_text(
        json.dumps({"claudeAiOauth": {"accessToken": "test-token", "expiresAt": 1}})
    )
    assert collector.claude_token(str(tmp_path)) == (None, "token stale")
    credential.write_text(json.dumps({"claudeAiOauth": {"accessToken": "test-token"}}))
    assert collector.claude_token(str(tmp_path)) == ("test-token", "")
