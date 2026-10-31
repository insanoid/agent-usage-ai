"""Configured, read-only access to the existing usage collector."""

from __future__ import annotations

import copy
import json
import os
import threading
import time
from pathlib import Path
from typing import Any

from agent_usage.backend import collector as _collector

CACHE_SECONDS = 60


class ConfigurationError(ValueError):
    """The subscriptions file is missing or invalid."""


def default_config() -> Path:
    """Return the Linux configuration path, respecting XDG_CONFIG_HOME."""
    root = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    return root / "agent-usage" / "subscriptions.json"


def read_accounts(path: Path) -> list[dict[str, Any]]:
    """Validate configuration before passing it to the shared collector."""
    try:
        doc = json.loads(path.read_text())
    except (OSError, ValueError) as exc:
        raise ConfigurationError(f"Cannot read subscriptions file: {path}") from exc
    if not isinstance(doc, dict) or doc.get("version") != 1:
        raise ConfigurationError("Subscriptions must be an object with version 1.")
    subscriptions = doc.get("subscriptions")
    if not isinstance(subscriptions, list) or not subscriptions:
        raise ConfigurationError("Add at least one subscription to the subscriptions file.")
    names: dict[str, str] = {}
    for sub in subscriptions:
        validate_subscription(sub, names)
    try:
        return _collector.accounts_from_config(str(path))
    except _collector.ConfigError as exc:
        raise ConfigurationError(str(exc)) from exc


def validate_subscription(sub: Any, names: dict[str, str]) -> None:
    """Reject invalid entries and display names that collide as account slots."""
    if not isinstance(sub, dict):
        raise ConfigurationError("Each subscription must be an object.")
    if sub.get("provider") not in ("claude", "codex"):
        raise ConfigurationError("Subscription provider must be claude or codex.")
    for field in ("name", "dir"):
        if not isinstance(sub.get(field), str) or not sub[field].strip():
            raise ConfigurationError(f"Subscription {field} must be a non-empty string.")
    name = sub["name"].strip()
    slot = _collector.account_slot(name)
    if slot in names and names[slot] != name:
        raise ConfigurationError("Subscription names must produce distinct account slots.")
    names[slot] = name
    if not Path(sub["dir"].strip()).expanduser().is_absolute():
        raise ConfigurationError("Subscription dir must be an absolute path or start with ~/.")


class UsageService:
    """Read configured subscriptions with a short, process-local report cache."""

    def __init__(self, config: Path, free_resets: bool = False) -> None:
        self.config = config.expanduser().resolve()
        self.free_resets = free_resets
        self._lock = threading.Lock()
        self._report: dict[str, Any] | None = None
        self._accounts: list[dict[str, Any]] | None = None
        self._expires = 0.0

    def subscriptions(self) -> list[dict[str, Any]]:
        """List configured profiles without reading or returning credentials."""
        return [
            {
                "slot": account["slot"],
                "name": account["label"],
                "providers": [
                    provider
                    for provider, key in (("claude", "claude_dir"), ("codex", "codex_home"))
                    if account[key]
                ],
            }
            for account in read_accounts(self.config)
        ]

    def report(self, refresh: bool = False) -> dict[str, Any]:
        """Return usage, preserving provider failures as notes, never as zero usage."""
        with self._lock:
            accounts = read_accounts(self.config)
            if refresh or accounts != self._accounts or time.monotonic() >= self._expires:
                entries = _collector.collect(accounts, free_resets=self.free_resets)
                for entry in entries:
                    usage = entry.get("claude")
                    if usage and usage.get("note", "").startswith("token stale"):
                        usage["note"] = (
                            "token stale — open Claude Code for this subscription to refresh"
                        )
                self._report = {
                    "version": _collector.JSON_SCHEMA_VERSION,
                    "generated_at": _collector.iso_utc(time.time()),
                    "accounts": entries,
                    "order": _collector.provider_order(accounts),
                }
                self._accounts = accounts
                self._expires = time.monotonic() + CACHE_SECONDS
            return copy.deepcopy(self._report)
