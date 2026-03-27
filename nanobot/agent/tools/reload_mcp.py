"""Tool to reload MCP servers without restarting the process."""

from __future__ import annotations

from typing import TYPE_CHECKING, Any

from nanobot.agent.tools.base import Tool

if TYPE_CHECKING:
    from nanobot.agent.loop import AgentLoop


class ReloadMCPTool(Tool):
    """Reload MCP server connections by re-reading config and reconnecting."""

    def __init__(self, agent_loop: AgentLoop):
        self._agent_loop = agent_loop

    @property
    def name(self) -> str:
        return "reload_mcp"

    @property
    def description(self) -> str:
        return (
            "Reload MCP servers without restarting. "
            "Re-reads config.json and reconnects all MCP servers. "
            "Use after adding, removing, or changing MCP server settings."
        )

    @property
    def parameters(self) -> dict[str, Any]:
        return {
            "type": "object",
            "properties": {},
            "required": [],
        }

    async def execute(self, **kwargs: Any) -> str:
        return await self._agent_loop.reconnect_mcp()
