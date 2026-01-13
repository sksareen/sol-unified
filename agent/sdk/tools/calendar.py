"""
Calendar tool for fetching events from Sol Unified.
"""

from datetime import datetime
from typing import Any
import httpx

from ..config import get_config


CALENDAR_TOOL = {
    "name": "get_calendar_events",
    "description": "Fetch calendar events for a specific date from Sol Unified. Returns events with attendee information to identify external meetings that need preparation.",
    "input_schema": {
        "type": "object",
        "properties": {
            "date": {
                "type": "string",
                "description": "Date in YYYY-MM-DD format. Defaults to today if not specified."
            }
        },
        "required": []
    }
}


async def get_calendar_events(date: str | None = None) -> dict[str, Any]:
    """
    Fetch calendar events for a specific date.

    Args:
        date: Date in YYYY-MM-DD format. Defaults to today.

    Returns:
        Dictionary containing events list with attendee info.
    """
    config = get_config()
    base_url = config.api.sol_unified_url

    if date is None:
        date = datetime.now().strftime("%Y-%m-%d")

    async with httpx.AsyncClient(timeout=config.api.timeout_seconds) as client:
        try:
            response = await client.get(
                f"{base_url}/calendar/events",
                params={"date": date}
            )
            response.raise_for_status()
            return response.json()
        except httpx.HTTPStatusError as e:
            return {"error": f"HTTP error: {e.response.status_code}", "events": []}
        except httpx.ConnectError:
            return {"error": "Cannot connect to Sol Unified. Is it running?", "events": []}
        except Exception as e:
            return {"error": str(e), "events": []}


def execute(args: dict[str, Any]) -> dict[str, Any]:
    """Synchronous wrapper for tool execution."""
    import asyncio
    return asyncio.run(get_calendar_events(args.get("date")))
