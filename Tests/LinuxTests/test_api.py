"""API boundaries: authentication, snapshot durability, and collection isolation."""

import json
import threading
from datetime import datetime, timezone
from pathlib import Path

import pytest
from agent_usage.api import create_app, read_token
from agent_usage.snapshot import SnapshotStore
from starlette.testclient import TestClient

TOKEN = "test-only-token-not-a-real-secret-12345"
AUTH = {"Authorization": f"Bearer {TOKEN}"}


def report() -> dict:
    return {
        "version": 1,
        "generated_at": datetime.fromtimestamp(1000, timezone.utc).isoformat(),
        "accounts": [
            {"slot": "work", "label": "Work", "claude": {"note": "token stale"}, "codex": None}
        ],
        "order": {"claude": ["work"], "codex": []},
    }


def test_authentication_and_empty_startup(tmp_path: Path) -> None:
    store = SnapshotStore(tmp_path / "snapshot.json", clock=lambda: 1000)
    client = TestClient(create_app(store, TOKEN))
    assert client.get("/v1/usage").status_code == 401
    assert client.get("/v1/usage", headers={"Authorization": "Bearer wrong"}).status_code == 401
    response = client.get("/v1/usage", headers=AUTH)
    assert response.status_code == 503
    assert response.json() == {"error": "Usage is not available yet"}
    assert response.headers["cache-control"] == "no-store"


def test_snapshot_reads_never_collect_and_survive_restart(tmp_path: Path) -> None:
    now = [1000.0]
    path = tmp_path / "snapshot.json"
    store = SnapshotStore(path, clock=lambda: now[0])
    assert store.refresh(report)
    client = TestClient(create_app(store, TOKEN))
    for _ in range(3):
        result = client.get("/v1/usage", headers=AUTH).json()
        assert result["accounts"][0]["claude"] == {"note": "token stale"}
        assert result["collection"] == {"age_seconds": 0, "stale": False, "status": "ok"}
    assert path.stat().st_mode & 0o777 == 0o600
    now[0] = 1601
    restored = SnapshotStore(path, clock=lambda: now[0]).read()
    assert restored["generated_at"] == report()["generated_at"]
    assert restored["collection"]["stale"] is True


def test_failed_collection_preserves_data_and_error_status(tmp_path: Path) -> None:
    path = tmp_path / "snapshot.json"
    store = SnapshotStore(path, clock=lambda: 1001)
    store.refresh(report)

    def failure() -> dict:
        raise RuntimeError("sensitive provider response")

    assert store.refresh(failure) is False
    result = store.read()
    assert result["accounts"] == report()["accounts"]
    assert result["collection"]["status"] == "failed"
    assert "sensitive" not in json.dumps(result)
    assert SnapshotStore(path, clock=lambda: 1001).read()["collection"]["status"] == "failed"


def test_slow_collection_does_not_block_reads_or_overlap(tmp_path: Path) -> None:
    store = SnapshotStore(tmp_path / "snapshot.json", clock=lambda: 1000)
    store.refresh(report)
    started, finish = threading.Event(), threading.Event()

    def slow() -> dict:
        started.set()
        assert finish.wait(5)
        return report()

    thread = threading.Thread(target=store.refresh, args=(slow,))
    thread.start()
    try:
        assert started.wait(2)
        assert store.read()["accounts"] == report()["accounts"]
        assert store.refresh(report) is False
    finally:
        finish.set()
        thread.join(5)
    assert not thread.is_alive()


def test_corrupt_disk_and_invalid_collection_do_not_replace_good_report(tmp_path: Path) -> None:
    path = tmp_path / "snapshot.json"
    path.write_text("invalid")
    store = SnapshotStore(path, clock=lambda: 1000)
    assert store.read() is None
    store.refresh(report)
    assert not store.refresh(lambda: {"version": 77})
    assert store.read()["accounts"] == report()["accounts"]


def test_token_file_requires_private_permissions_and_long_token(tmp_path: Path) -> None:
    path = tmp_path / "token"
    path.write_text(TOKEN + "\n")
    path.chmod(0o600)
    assert read_token(path) == TOKEN
    path.chmod(0o644)
    with pytest.raises(ValueError):
        read_token(path)
    path.chmod(0o600)
    path.write_text("short")
    with pytest.raises(ValueError):
        read_token(path)


def test_raw_provider_errors_never_reach_api_or_disk(tmp_path: Path) -> None:
    path = tmp_path / "snapshot.json"
    store = SnapshotStore(path, clock=lambda: 1000)
    value = report()
    value["accounts"][0]["codex"] = {"note": "Cannot read /home/private/.codex/auth.json: secret"}
    store.refresh(lambda: value)
    response = TestClient(create_app(store, TOKEN)).get("/v1/usage", headers=AUTH)
    assert response.json()["accounts"][0]["codex"]["note"] == "Provider usage is unavailable"
    assert "/home/private" not in path.read_text()


@pytest.mark.parametrize(
    "invalid", [None, {"slot": "work", "label": "Work", "codex": {"limits": [None]}}]
)
def test_invalid_accounts_cannot_replace_good_data(tmp_path: Path, invalid: object) -> None:
    store = SnapshotStore(tmp_path / "snapshot.json", clock=lambda: 1000)
    store.refresh(report)
    broken = report()
    broken["accounts"] = [invalid]
    assert store.refresh(lambda: broken) is False
    assert store.read()["accounts"] == report()["accounts"]


def test_nonfinite_restored_snapshot_is_rejected(tmp_path: Path) -> None:
    path = tmp_path / "snapshot.json"
    broken = report()
    broken["accounts"][0]["codex"] = {
        "limits": [{"kind": "weekly_all", "label": "Weekly", "percent": float("nan")}]
    }
    path.write_text(json.dumps({"report": broken}))
    assert SnapshotStore(path).read() is None


def test_lifespan_collects_without_delaying_startup(tmp_path: Path) -> None:
    from agent_usage.snapshot import CollectionWorker

    store = SnapshotStore(tmp_path / "snapshot.json", clock=lambda: 1000)
    started, finish = threading.Event(), threading.Event()

    def slow() -> dict:
        started.set()
        assert finish.wait(5)
        return report()

    with TestClient(create_app(store, TOKEN, CollectionWorker(store, slow))) as client:
        try:
            assert started.wait(2)
            assert client.get("/v1/usage", headers=AUTH).status_code == 503
        finally:
            finish.set()
    assert store.read()["accounts"] == report()["accounts"]
