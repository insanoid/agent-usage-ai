"""Local stdio MCP tools; configuration is supplied by the host, never a tool."""

from typing import Any

from mcp.server.fastmcp import FastMCP
from mcp.types import ToolAnnotations

from agent_usage.service import UsageService


def create_server(service: UsageService) -> FastMCP:
    """Build a server exposing usage reports and configured subscription names."""
    server = FastMCP("Agent Usage")
    annotations = ToolAnnotations(readOnlyHint=True, destructiveHint=False, openWorldHint=True)

    @server.tool(annotations=annotations)
    def list_subscriptions() -> dict[str, Any]:
        """List configured subscription names, slots, and providers. No credentials or paths."""
        return {"subscriptions": service.subscriptions()}

    @server.tool(annotations=annotations)
    def get_usage(refresh: bool = False) -> dict[str, Any]:
        """Read Claude Code and Codex usage, plans, reset times, and extra usage.

        Reports are cached for 60 seconds. Use refresh=true to fetch again.
        Percent is usage consumed, not remaining. A provider note means its
        usage is unavailable; never treat unavailable usage as zero.
        """
        return service.report(refresh=refresh)

    return server
