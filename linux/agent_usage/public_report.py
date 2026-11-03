"""Validate and redact reports at the network boundary without changing MCP."""

from __future__ import annotations

import json
import re
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

SAFE_NOTES = frozenset(
    {
        "no directory",
        "not logged in",
        "credential unreadable",
        "no access token",
        "token stale",
        "token stale — open Claude Code for this subscription to refresh",
        "rate limited — try again in a few minutes",
        "no codex home",
        "codex not installed",
        "no response",
        "app-server failed",
        "Provider usage is unavailable",
    }
)


class PublicModel(BaseModel):
    """Drop unrecognized fields and reject invalid types and nonfinite numbers."""

    model_config = ConfigDict(strict=True, allow_inf_nan=False, extra="ignore")


class Limit(PublicModel):
    kind: str
    label: str
    percent: float
    scope: str | None = None
    severity: str | None = None
    resets_at: str | None = None


class Spend(PublicModel):
    used: float | None = None
    limit: float | None = None
    currency: str | None = None
    percent: float | None = None
    enabled: bool = False
    disabled_reason: str | None = None


class Breakdown(PublicModel):
    name: str
    percent: float


class Provider(PublicModel):
    note: str | None = None
    limits: list[Limit] = Field(default_factory=list)
    plan: str | None = None
    plan_detail: str | None = None
    spend: Spend | None = None
    breakdown: list[Breakdown] = Field(default_factory=list)
    reset_credits: int | None = None
    reset_credits_expire_at: str | None = None


class Account(PublicModel):
    slot: str = Field(min_length=1)
    label: str = Field(min_length=1)
    claude: Provider | None = None
    codex: Provider | None = None


class Report(PublicModel):
    version: Literal[1]
    generated_at: str
    accounts: list[Account] = Field(min_length=1)
    order: dict[str, list[str]] = Field(default_factory=dict)


def public_report(value: dict) -> dict:
    """Return a typed report with raw provider diagnostics replaced by safe notes."""
    json.dumps(value, allow_nan=False)
    report = Report.model_validate(value).model_dump(exclude_unset=True)
    for account in report["accounts"]:
        for name in ("claude", "codex"):
            provider = account.get(name)
            if provider and provider.get("note"):
                note = provider["note"]
                if note not in SAFE_NOTES and not re.fullmatch(r"HTTP [1-5][0-9]{2}", note):
                    provider["note"] = "Provider usage is unavailable"
    return report
