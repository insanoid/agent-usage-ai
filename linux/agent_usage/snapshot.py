"""Durable usage snapshots; network collection never holds the reader lock."""

from __future__ import annotations

import copy
import json
import logging
import os
import tempfile
import threading
import time
from collections.abc import Callable
from datetime import datetime
from pathlib import Path
from typing import Any

from agent_usage.public_report import public_report

COLLECTION_SECONDS = 300
STALE_SECONDS = 600
LOGGER = logging.getLogger(__name__)
Report = dict[str, Any]


def generated_timestamp(report: Report) -> float:
    """Validate the report envelope before publishing or restoring it."""
    if not isinstance(report, dict) or report.get("version") != 1:
        raise ValueError("Unsupported report")
    if not isinstance(report.get("accounts"), list) or not report["accounts"]:
        raise ValueError("Missing accounts")
    stamp = datetime.fromisoformat(report["generated_at"].replace("Z", "+00:00"))
    if stamp.tzinfo is None:
        raise ValueError("Timestamp must include timezone")
    return stamp.timestamp()


def atomic_write(path: Path, value: Report) -> None:
    """Replace a private snapshot atomically, never leaving a partial JSON file."""
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=".snapshot-", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w") as handle:
            json.dump(value, handle, allow_nan=False)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


class SnapshotStore:
    """Keep the last completed report and its collection status across restarts."""

    def __init__(self, path: Path, clock: Callable[[], float] = time.time) -> None:
        self.path = path
        self.clock = clock
        self._reader_lock = threading.Lock()
        self._collection_lock = threading.Lock()
        self._report: Report | None = None
        self._failed = False
        self._restore()

    def _restore(self) -> None:
        try:
            saved = json.loads(self.path.read_text())
            restored = public_report(saved["report"])
            generated_timestamp(restored)
            self._report = restored
            self._failed = bool(saved.get("failed", False))
        except FileNotFoundError:
            return
        except (OSError, ValueError, TypeError, KeyError, AttributeError):
            LOGGER.warning("Stored usage snapshot is unreadable; waiting for collection")

    def read(self) -> Report | None:
        """Return an isolated copy with freshness computed at request time."""
        with self._reader_lock:
            if self._report is None:
                return None
            result = copy.deepcopy(self._report)
            age = max(0, int(self.clock() - generated_timestamp(result)))
            result["collection"] = {
                "age_seconds": age,
                "stale": age > STALE_SECONDS,
                "status": "failed" if self._failed else "ok",
            }
            return result

    def refresh(self, collect: Callable[[], Report]) -> bool:
        """Publish one collection; skip overlap and retain data on any failure."""
        if not self._collection_lock.acquire(blocking=False):
            return False
        try:
            report = public_report(collect())
            generated_timestamp(report)
            atomic_write(self.path, {"report": report, "failed": False})
            with self._reader_lock:
                self._report = copy.deepcopy(report)
                self._failed = False
            return True
        except Exception as exc:  # noqa: BLE001 — isolate provider failures without leaking their messages
            # Provider exception messages may contain sensitive data.
            LOGGER.warning("Usage collection failed (%s)", type(exc).__name__)
            self._record_failure()
            return False
        finally:
            self._collection_lock.release()

    def _record_failure(self) -> None:
        with self._reader_lock:
            self._failed = True
            previous = copy.deepcopy(self._report)
        if previous is not None:
            try:
                atomic_write(self.path, {"report": previous, "failed": True})
            except OSError:
                LOGGER.warning("Could not persist collection failure status")


class CollectionWorker:
    """Run one bounded provider collection at a time, independently of HTTP reads."""

    def __init__(self, store: SnapshotStore, collect: Callable[[], Report]) -> None:
        self.store = store
        self.collect = collect
        self._stop = threading.Event()
        self._thread = threading.Thread(target=self._run, name="usage-collector", daemon=True)

    def start(self) -> None:
        """Start the background collector immediately."""
        self._thread.start()

    def stop(self) -> None:
        """Stop scheduling work and allow the current provider requests to finish."""
        self._stop.set()
        self._thread.join(timeout=50)
        if self._thread.is_alive():
            LOGGER.warning("Collector did not finish before shutdown timeout")

    def _run(self) -> None:
        while not self._stop.is_set():
            started = time.monotonic()
            self.store.refresh(self.collect)
            self._stop.wait(max(0, COLLECTION_SECONDS - (time.monotonic() - started)))
