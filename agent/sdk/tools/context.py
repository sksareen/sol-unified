"""
Context tools for fetching work context and clipboard from Sol Unified.
"""

from typing import Any
import httpx

from ..config import get_config


CONTEXT_TOOL = {
    "name": "get_context",
    "description": "Get the user's current work context from Sol Unified, including active session, focus score, recent activity, and what they're working on.",
    "input_schema": {
        "type": "object",
        "properties": {},
        "required": []
    }
}


CLIPBOARD_TOOL = {
    "name": "get_clipboard",
    "description": "Get recent clipboard items from Sol Unified. Useful for understanding what the user has been copying/pasting.",
    "input_schema": {
        "type": "object",
        "properties": {
            "limit": {
                "type": "integer",
                "description": "Maximum number of clipboard items to return. Default 10.",
                "default": 10
            },
            "app": {
                "type": "string",
                "description": "Filter by source application name (optional)."
            }
        },
        "required": []
    }
}


async def get_context() -> dict[str, Any]:
    """
    Get the user's current work context.

    Returns:
        Dictionary containing active context, focus score, recent activity.
    """
    config = get_config()
    base_url = config.api.sol_unified_url

    async with httpx.AsyncClient(timeout=config.api.timeout_seconds) as client:
        try:
            response = await client.get(f"{base_url}/context")
            response.raise_for_status()
            return response.json()
        except httpx.HTTPStatusError as e:
            return {"error": f"HTTP error: {e.response.status_code}"}
        except httpx.ConnectError:
            return {"error": "Cannot connect to Sol Unified. Is it running?"}
        except Exception as e:
            return {"error": str(e)}


async def get_clipboard(limit: int = 10, app: str | None = None) -> dict[str, Any]:
    """
    Get recent clipboard items.

    Args:
        limit: Maximum number of items to return.
        app: Filter by source application name.

    Returns:
        Dictionary containing clipboard items list.
    """
    config = get_config()
    base_url = config.api.sol_unified_url

    params = {"limit": limit}
    if app:
        params["app"] = app

    async with httpx.AsyncClient(timeout=config.api.timeout_seconds) as client:
        try:
            response = await client.get(f"{base_url}/clipboard", params=params)
            response.raise_for_status()
            return response.json()
        except httpx.HTTPStatusError as e:
            return {"error": f"HTTP error: {e.response.status_code}", "items": []}
        except httpx.ConnectError:
            return {"error": "Cannot connect to Sol Unified. Is it running?", "items": []}
        except Exception as e:
            return {"error": str(e), "items": []}


def execute_context(args: dict[str, Any]) -> dict[str, Any]:
    """Synchronous wrapper for context tool execution."""
    import asyncio
    return asyncio.run(get_context())


def execute_clipboard(args: dict[str, Any]) -> dict[str, Any]:
    """Synchronous wrapper for clipboard tool execution."""
    import asyncio
    return asyncio.run(get_clipboard(
        limit=args.get("limit", 10),
        app=args.get("app")
    ))
