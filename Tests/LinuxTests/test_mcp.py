"""Exercise the actual stdio protocol with the official MCP client."""

import asyncio
import json
import sys
from datetime import timedelta
from pathlib import Path

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


def test_stdio_tools_and_errors(tmp_path: Path) -> None:
    config = tmp_path / "subscriptions.json"
    config.write_text(
        json.dumps(
            {
                "version": 1,
                "subscriptions": [
                    {"name": "Missing login", "provider": "codex", "dir": str(tmp_path / "missing")}
                ],
            }
        )
    )

    async def exercise() -> None:
        params = StdioServerParameters(
            command=sys.executable,
            args=[
                "-c",
                "from agent_usage.cli import main; raise SystemExit(main())",
                "--mcp",
                "--config",
                str(config),
            ],
        )
        async with (
            stdio_client(params) as (reader, writer),
            ClientSession(reader, writer, read_timeout_seconds=timedelta(seconds=15)) as session,
        ):
            await session.initialize()
            listed = await session.list_tools()
            assert {t.name for t in listed.tools} == {"get_usage", "list_subscriptions"}
            assert all(t.annotations.readOnlyHint for t in listed.tools)
            subscriptions = await session.call_tool("list_subscriptions", {})
            assert not subscriptions.isError
            assert str(tmp_path) not in str(subscriptions.content)
            report = await session.call_tool("get_usage", {})
            assert not report.isError
            data = report.structuredContent
            assert data["accounts"][0]["codex"] == {"note": "not logged in"}
            refreshed = await session.call_tool("get_usage", {"refresh": True})
            assert not refreshed.isError
            unknown = await session.call_tool("not_a_tool", {})
            assert unknown.isError
            config.write_text("invalid JSON")
            failed = await session.call_tool("get_usage", {})
            assert failed.isError

    asyncio.run(exercise())
