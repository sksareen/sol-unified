"""
Custom tools for Sol Unified Agent.

These tools connect to Sol Unified's HTTP API to access:
- Calendar events
- People CRM (lookup, create, update contacts)
- Work context and clipboard
- Action submission
"""

from .calendar import get_calendar_events, CALENDAR_TOOL
from .context import get_context, get_clipboard, CONTEXT_TOOL, CLIPBOARD_TOOL
from .actions import create_action, ACTION_TOOL
from .people import (
    lookup_person,
    create_contact,
    update_contact,
    PEOPLE_TOOL,
    CREATE_CONTACT_TOOL,
    UPDATE_CONTACT_TOOL,
)

ALL_TOOLS = [
    CALENDAR_TOOL,
    CONTEXT_TOOL,
    CLIPBOARD_TOOL,
    ACTION_TOOL,
    PEOPLE_TOOL,
    CREATE_CONTACT_TOOL,
    UPDATE_CONTACT_TOOL,
]

__all__ = [
    "get_calendar_events",
    "get_context",
    "get_clipboard",
    "create_action",
    "lookup_person",
    "create_contact",
    "update_contact",
    "ALL_TOOLS",
    "CALENDAR_TOOL",
    "CONTEXT_TOOL",
    "CLIPBOARD_TOOL",
    "ACTION_TOOL",
    "PEOPLE_TOOL",
    "CREATE_CONTACT_TOOL",
    "UPDATE_CONTACT_TOOL",
]
