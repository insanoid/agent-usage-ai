"""Terminal command and local MCP entry point."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

from agent_usage.backend import collector as _collector
from agent_usage.service import ConfigurationError, UsageService, default_config


def main(argv: list[str] | None = None) -> int:
    """Print usage or serve MCP over stdio; diagnostics always go to stderr."""
    parser = argparse.ArgumentParser(description="Claude Code and Codex subscription usage.")
    parser.add_argument(
        "--config", type=Path, default=default_config(), help="subscriptions JSON file"
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--json", action="store_true", help="print the full usage report as JSON")
    mode.add_argument("--mcp", action="store_true", help="run the local MCP stdio server")
    parser.add_argument(
        "--free-resets",
        action="store_true",
        default=os.environ.get("AGENT_USAGE_FREE_RESETS") == "1",
        help="opt in to Claude's undocumented free-reset lookup",
    )
    args = parser.parse_args(argv)
    service = UsageService(args.config, free_resets=args.free_resets)
    try:
        service.subscriptions()
        if args.mcp:
            from agent_usage.server import create_server

            create_server(service).run(transport="stdio")
        else:
            report = service.report()
            if args.json:
                print(json.dumps(report, ensure_ascii=False))
            else:
                _collector.print_table(report["accounts"])
    except ConfigurationError as exc:
        print(f"agent-usage: {exc}", file=sys.stderr)
        return 2
    return 0
