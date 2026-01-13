"""
Actions tool for submitting agent actions to Sol Unified for user approval.
"""

from typing import Any, Literal
import httpx
import json

from ..config import get_config


ActionType = Literal[
    "meeting_brief",
    "email_draft",
    "linkedin_draft",
    "research_summary",
    "reminder",
    "other"
]


ACTION_TOOL = {
    "name": "create_action",
    "description": "Submit an action (like a meeting brief, email draft, etc.) to Sol Unified for user review and approval. The user will see this in their Action Queue and can approve or dismiss it.",
    "input_schema": {
        "type": "object",
        "properties": {
            "type": {
                "type": "string",
                "enum": ["meeting_brief", "email_draft", "linkedin_draft", "research_summary", "reminder", "other"],
                "description": "The type of action being created."
            },
            "title": {
                "type": "string",
                "description": "Short title for the action (shown in list view)."
            },
            "summary": {
                "type": "string",
                "description": "Brief summary of what this action contains."
            },
            "draft_content": {
                "type": "string",
                "description": "The full content - meeting brief, draft message, research notes, etc."
            },
            "related_event_id": {
                "type": "string",
                "description": "Calendar event ID this action relates to (optional)."
            },
            "related_event_title": {
                "type": "string",
                "description": "Calendar event title for display (optional)."
            },
            "action_url": {
                "type": "string",
                "description": "URL to open when user takes action (optional)."
            }
        },
        "required": ["type", "title", "summary"]
    }
}


async def create_action(
    type: ActionType,
    title: str,
    summary: str,
    draft_content: str | None = None,
    related_event_id: str | None = None,
    related_event_title: str | None = None,
    action_url: str | None = None,
) -> dict[str, Any]:
    """
    Submit an action to Sol Unified for user approval.

    Args:
        type: Type of action (meeting_brief, email_draft, etc.)
        title: Short title for the action
        summary: Brief summary
        draft_content: Full content of the action
        related_event_id: Associated calendar event ID
        related_event_title: Associated calendar event title
        action_url: URL to open when actioned

    Returns:
        Dictionary with success status and action ID.
    """
    config = get_config()
    base_url = config.api.sol_unified_url

    payload = {
        "type": type,
        "title": title,
        "summary": summary,
    }

    if draft_content:
        payload["draftContent"] = draft_content
    if related_event_id:
        payload["relatedEventId"] = related_event_id
    if related_event_title:
        payload["relatedEventTitle"] = related_event_title
    if action_url:
        payload["actionUrl"] = action_url

    async with httpx.AsyncClient(timeout=config.api.timeout_seconds) as client:
        try:
            response = await client.post(
                f"{base_url}/agent/actions",
                json=payload,
                headers={"Content-Type": "application/json"}
            )
            response.raise_for_status()
            return response.json()
        except httpx.HTTPStatusError as e:
            return {"success": False, "error": f"HTTP error: {e.response.status_code}"}
        except httpx.ConnectError:
            return {"success": False, "error": "Cannot connect to Sol Unified. Is it running?"}
        except Exception as e:
            return {"success": False, "error": str(e)}


def execute(args: dict[str, Any]) -> dict[str, Any]:
    """Synchronous wrapper for tool execution."""
    import asyncio
    return asyncio.run(create_action(
        type=args["type"],
        title=args["title"],
        summary=args["summary"],
        draft_content=args.get("draft_content"),
        related_event_id=args.get("related_event_id"),
        related_event_title=args.get("related_event_title"),
        action_url=args.get("action_url"),
    ))
