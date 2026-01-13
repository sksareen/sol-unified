"""
Custom tools for Sol Unified Agent.

These tools connect to Sol Unified's HTTP API to access:
- Calendar events
- People CRM
- Work context and clipboard
- Action submission
"""

from .calendar import get_calendar_events, CALENDAR_TOOL
from .context import get_context, get_clipboard, CONTEXT_TOOL, CLIPBOARD_TOOL
from .actions import create_action, ACTION_TOOL
from .people import lookup_person, PEOPLE_TOOL

ALL_TOOLS = [CALENDAR_TOOL, CONTEXT_TOOL, CLIPBOARD_TOOL, ACTION_TOOL, PEOPLE_TOOL]

__all__ = [
    "get_calendar_events",
    "get_context",
    "get_clipboard",
    "create_action",
    "lookup_person",
    "ALL_TOOLS",
    "CALENDAR_TOOL",
    "CONTEXT_TOOL",
    "CLIPBOARD_TOOL",
    "ACTION_TOOL",
    "PEOPLE_TOOL",
]
