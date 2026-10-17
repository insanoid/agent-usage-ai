"""Unit tests for bin/agent-usage. No network, Keychain or Codex: every
outside call is replaced. Run with: uvx pytest Tests/ScriptTests"""

import io
import json
import subprocess
import sys
import time
from contextlib import redirect_stdout

import pytest


# --- accounts -----------------------------------------------------------------


@pytest.mark.parametrize(
    ("name", "slot"),
    [("Work", "work"), ("Work 2", "work-2"), ("  Ünï Work!! ", "n-work"), ("!!!", "account")],
)
def test_account_slot_matches_the_app(au, name, slot):
    assert au.account_slot(name) == slot


def write_config(tmp_path, subscriptions):
    path = tmp_path / "subscriptions.json"
    path.write_text(json.dumps({"version": 1, "subscriptions": subscriptions}))
    return str(path)


def test_config_pairs_subscriptions_by_name(au, tmp_path):
    path = write_config(
        tmp_path,
        [
            {"name": "Work", "provider": "claude", "dir": "/w/claude"},
            {"name": "Personal", "provider": "claude", "dir": "/p/claude"},
            {"name": "work", "provider": "codex", "dir": "/w/codex"},
        ],
    )
    accounts = au.accounts_from_config(path)
    assert [a["slot"] for a in accounts] == ["work", "personal"]
    assert accounts[0] == {
        "slot": "work",
        "label": "Work",
        "claude_dir": "/w/claude",
        "codex_home": "/w/codex",
        "claude_position": 0,
        "codex_position": 0,
    }
    assert accounts[1]["codex_home"] == ""


def test_config_allows_a_codex_only_account(au, tmp_path):
    path = write_config(tmp_path, [{"name": "Solo", "provider": "codex", "dir": "/s/codex"}])
    assert au.accounts_from_config(path) == [
        {"slot": "solo", "label": "Solo", "claude_dir": "", "codex_home": "/s/codex", "codex_position": 0}
    ]


def test_order_follows_each_providers_subscriptions(au, tmp_path):
    path = write_config(
        tmp_path,
        [
            {"name": "Work", "provider": "claude", "dir": "/w/claude"},
            {"name": "Personal", "provider": "codex", "dir": "/p/codex"},
            {"name": "Personal", "provider": "claude", "dir": "/p/claude"},
            {"name": "Work", "provider": "codex", "dir": "/w/codex"},
            {"name": "Solo", "provider": "codex", "dir": "/s/codex"},
        ],
    )
    assert au.provider_order(au.accounts_from_config(path)) == {
        "claude": ["work", "personal"],
        "codex": ["personal", "work", "solo"],
    }


def test_order_without_positions_keeps_account_order(au):
    accounts = [
        {"slot": "a", "claude_dir": "/a", "codex_home": ""},
        {"slot": "b", "claude_dir": "/b", "codex_home": "/b"},
    ]
    assert au.provider_order(accounts) == {"claude": ["a", "b"], "codex": ["b"]}


def test_config_expands_home(au, tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", "/home/me")
    path = write_config(tmp_path, [{"name": "W", "provider": "claude", "dir": "~/.claude-w"}])
    assert au.accounts_from_config(path)[0]["claude_dir"] == "/home/me/.claude-w"


@pytest.mark.parametrize(
    "subscriptions",
    [
        [{"name": "", "provider": "claude", "dir": "/x"}],
        [{"name": "W", "provider": "gemini", "dir": "/x"}],
        [{"name": "W", "provider": "claude", "dir": ""}],
        [
            {"name": "W", "provider": "claude", "dir": "/a"},
            {"name": "w", "provider": "claude", "dir": "/b"},
        ],
    ],
)
def test_config_rejects_bad_subscriptions(au, tmp_path, subscriptions):
    with pytest.raises(au.ConfigError):
        au.accounts_from_config(write_config(tmp_path, subscriptions))


def test_config_reports_an_unreadable_file(au, tmp_path):
    with pytest.raises(au.ConfigError, match="cannot read"):
        au.accounts_from_config(str(tmp_path / "missing.json"))


# --- labels -------------------------------------------------------------------


@pytest.mark.parametrize(
    ("org", "tier", "expected"),
    [
        ("claude_pro", "default_claude_ai", {"plan": "Pro", "plan_detail": None}),
        ("claude_max", "default_claude_max_20x", {"plan": "Max 20×", "plan_detail": None}),
        ("claude_team", "default_claude_max_5x", {"plan": "Team", "plan_detail": "Max 5×"}),
        ("claude_enterprise", None, {"plan": "Enterprise", "plan_detail": None}),
        ("claude_new_thing", None, {"plan": "New Thing", "plan_detail": None}),
    ],
)
def test_claude_plan_label(au, org, tier, expected):
    assert au.claude_plan_label(org, tier) == expected


@pytest.mark.parametrize(
    ("plan_type", "expected"),
    [
        ("prolite", {"plan": "Pro Lite", "plan_detail": None}),
        ("self_serve_business_prolite", {"plan": "Business", "plan_detail": "Pro Lite"}),
        ("plus", {"plan": "Plus", "plan_detail": None}),
        ("team_pro", {"plan": "Team", "plan_detail": "Pro"}),
        (None, {"plan": None, "plan_detail": None}),
    ],
)
def test_codex_plan_label(au, plan_type, expected):
    assert au.codex_plan_label(plan_type) == expected


@pytest.mark.parametrize(
    ("minutes", "label"),
    [(300, "5-hour"), (10080, "Weekly"), (1440, "1-day"), (2880, "2-day"), (90, "90-minute"), (0, "Window")],
)
def test_window_label(au, minutes, label):
    assert au.window_label(minutes) == label


# --- limits -------------------------------------------------------------------


def test_claude_limits_read_the_limits_list(au):
    limits = au.claude_limits(
        {
            "limits": [
                {"kind": "session", "percent": 12, "resets_at": "2026-10-16T14:19:59.057Z"},
                {"kind": "weekly_scoped", "percent": 100, "scope": {"model": {"display_name": "Fable"}}},
                {"kind": "weekly_all", "percent": None},
            ]
        }
    )
    assert [(lim["label"], lim["percent"]) for lim in limits] == [("5-hour", 12.0), ("Fable weekly", 100.0)]
    assert limits[0]["resets_at"] == "2026-10-16T14:19:59Z"


def test_unnamed_model_limit_never_counts_as_account_wide(au):
    limits = au.claude_limits({"limits": [{"kind": "weekly_scoped", "percent": 60, "scope": {"other": 1}}]})
    assert limits[0]["scope"] == "Other model"


def test_claude_limits_fall_back_to_the_fixed_windows(au):
    limits = au.claude_limits({"five_hour": {"utilization": 5}, "seven_day": {"utilization": 40}})
    assert [(lim["kind"], lim["percent"]) for lim in limits] == [("session", 5.0), ("weekly_all", 40.0)]


def test_codex_limits_read_every_bucket(au):
    limits = au.codex_limits(
        {
            "rateLimitsByLimitId": {
                "codex": {"primary": {"usedPercent": 14, "windowDurationMins": 10080, "resetsAt": 0}},
                "spark": {
                    "limitName": "Spark",
                    "primary": {"usedPercent": 50, "windowDurationMins": 300, "resetsAt": 3600},
                },
            }
        }
    )
    assert [(lim["kind"], lim["label"], lim["scope"]) for lim in limits] == [
        ("weekly_all", "Weekly", None),
        ("session_scoped", "Spark 5-hour", "Spark"),
    ]
    assert limits[1]["resets_at"] == "1970-01-01T01:00:00Z"


def test_spend_converts_minor_units(au):
    spend = au.claude_spend(
        {
            "used": {"amount_minor": 45512, "currency": "USD", "exponent": 2},
            "limit": {"amount_minor": 60000},
            "enabled": True,
        }
    )
    assert spend["used"] == 455.12
    assert spend["limit"] == 600.0
    assert spend["currency"] == "USD"


# --- free resets ----------------------------------------------------------------


def test_claude_resets_need_eligibility(au):
    assert au.claude_reset_grants({"eligible": False, "grants": [{"resets_left": 1}]}) == {
        "reset_credits": None,
        "reset_credits_expire_at": None,
    }


def test_claude_resets_count_only_live_grants(au):
    grants = [
        {"resets_left": 1, "ends_at": "2999-10-22T16:00:00+00:00"},
        {"resets_left": 2, "ends_at": "2999-01-01T00:00:00+00:00"},
        {"resets_left": 5, "paused": True},
        {"resets_left": 3, "ends_at": "2000-01-01T00:00:00+00:00"},
        {"resets_left": 0},
    ]
    assert au.claude_reset_grants({"eligible": True, "grants": grants}) == {
        "reset_credits": 3,
        "reset_credits_expire_at": "2999-01-01T00:00:00Z",
    }


def test_codex_resets_count_from_available_count(au):
    summary = {
        "availableCount": 3,
        "credits": [
            {"status": "available", "expiresAt": 1793000000},
            {"status": "redeemed", "expiresAt": 1792000000},
            {"status": "available", "expiresAt": 1792500000},
        ],
    }
    assert au.reset_credits(summary) == {
        "reset_credits": 3,
        "reset_credits_expire_at": "2026-10-20T12:40:00Z",
    }
    assert au.reset_credits(None) == {"reset_credits": None, "reset_credits_expire_at": None}


# --- keychain -------------------------------------------------------------------


def fake_security(found_services):
    calls = []

    def run(args, **_):
        service = args[args.index("-s") + 1]
        calls.append(service)
        ok = service in found_services
        return subprocess.CompletedProcess(args, 0 if ok else 44, stdout='{"token": 1}\n' if ok else "")

    return run, calls


def test_keychain_falls_back_to_the_plain_name_for_the_default_folder(au, monkeypatch):
    run, calls = fake_security({"Claude Code-credentials"})
    monkeypatch.setattr(au.subprocess, "run", run)
    assert au.keychain_credential(au.DEFAULT_CLAUDE_DIR) == '{"token": 1}'
    assert calls[-1] == "Claude Code-credentials"


def test_keychain_uses_only_the_hashed_name_elsewhere(au, monkeypatch):
    run, calls = fake_security({"Claude Code-credentials"})
    monkeypatch.setattr(au.subprocess, "run", run)
    assert au.keychain_credential("/somewhere/else") is None
    assert len(calls) == 1 and calls[0].startswith("Claude Code-credentials-")


# --- robustness and output ------------------------------------------------------


def test_one_failing_account_does_not_fail_the_rest(au, capsys):
    def boom(_):
        raise ValueError("bad timestamp")

    assert au.guarded(boom, "x") == {"note": "internal error: ValueError"}
    assert "bad timestamp" in capsys.readouterr().err


def test_json_output_for_a_config(au, tmp_path, monkeypatch):
    path = write_config(
        tmp_path,
        [
            {"name": "Work", "provider": "claude", "dir": "/w/claude"},
            {"name": "Work", "provider": "codex", "dir": "/w/codex"},
            {"name": "Solo", "provider": "codex", "dir": "/s/codex"},
        ],
    )
    monkeypatch.setattr(au, "claude_usage", lambda d, free_resets=False: {"limits": [], "plan": "Pro", "dir": d})
    monkeypatch.setattr(au, "codex_usage", lambda d: {"limits": [], "dir": d})
    monkeypatch.setattr(sys, "argv", ["agent-usage", "--json", "--config", path])
    out = io.StringIO()
    with redirect_stdout(out):
        assert au.main() == 0
    doc = json.loads(out.getvalue())
    assert doc["version"] == au.JSON_SCHEMA_VERSION
    assert [(a["slot"], (a["claude"] or {}).get("dir"), a["codex"]["dir"]) for a in doc["accounts"]] == [
        ("work", "/w/claude", "/w/codex"),
        ("solo", None, "/s/codex"),
    ]


def test_bad_config_exits_2(au, tmp_path, monkeypatch, capsys):
    monkeypatch.setattr(sys, "argv", ["agent-usage", "--config", str(tmp_path / "nope.json")])
    assert au.main() == 2
    assert "cannot read" in capsys.readouterr().err


def test_iso_utc_normalises_strings_and_epochs(au):
    assert au.iso_utc("2026-10-16T14:19:59.057075+00:00") == "2026-10-16T14:19:59Z"
    assert au.iso_utc(0) == "1970-01-01T00:00:00Z"
    assert au.iso_utc(None) is None


def test_human_delta(au):
    assert au.human_delta(-5) == "now"
    assert au.human_delta(21 * 60) == "21m"
    assert au.human_delta(3 * 3600 + 7 * 60) == "3h07m"
    assert au.human_delta(4 * 86400 + 3 * 3600) == "4d3h"
    assert time.time() > 0


# --- free resets are opt-in ------------------------------------------------------


class FakeResponse(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False


def capture_usage_request(au, monkeypatch, free_resets):
    seen = {}

    def urlopen(req, timeout):
        seen["url"] = req.full_url
        seen["headers"] = {k.lower(): v for k, v in req.header_items()}
        return FakeResponse(json.dumps({"limits": []}).encode())

    monkeypatch.setattr(au, "claude_token", lambda _: ("token", ""))
    monkeypatch.setattr(au, "claude_plan", lambda *_: {"plan": None, "plan_detail": None})
    monkeypatch.setattr(au.urllib.request, "urlopen", urlopen)
    au.claude_usage("/w/claude", free_resets=free_resets)
    return seen


def test_default_request_does_not_identify_as_claude_code(au, monkeypatch):
    seen = capture_usage_request(au, monkeypatch, free_resets=False)
    assert "cedar_ember" not in seen["url"]
    assert "x-app" not in seen["headers"]
    assert "claude-cli" not in seen["headers"].get("user-agent", "")


def test_free_resets_opt_in_identifies_as_claude_code(au, monkeypatch):
    seen = capture_usage_request(au, monkeypatch, free_resets=True)
    assert seen["url"].endswith("?cedar_ember=1")
    assert seen["headers"]["x-app"] == "cli"
    assert seen["headers"]["user-agent"].startswith("claude-cli/")


def test_free_resets_flag_reaches_every_claude_call(au, tmp_path, monkeypatch):
    path = write_config(tmp_path, [{"name": "W", "provider": "claude", "dir": "/w/claude"}])
    calls = []
    monkeypatch.setattr(au, "claude_usage", lambda d, free_resets=False: calls.append(free_resets) or {"limits": []})
    monkeypatch.setattr(sys, "argv", ["agent-usage", "--json", "--free-resets", "--config", path])
    with redirect_stdout(io.StringIO()):
        assert au.main() == 0
    assert calls == [True]
