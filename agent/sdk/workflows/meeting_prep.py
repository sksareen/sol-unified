"""
Meeting prep workflow using Claude Agent SDK.

This workflow:
1. Fetches upcoming calendar events with external attendees
2. Looks up attendees in People CRM
3. Gathers relevant context
4. Uses Claude to generate a meeting brief
5. Submits the brief as an action for user review
"""

import asyncio
from datetime import datetime, timedelta
from typing import Any
import anthropic

from ..config import get_config
from ..tools.calendar import get_calendar_events
from ..tools.people import lookup_person
from ..tools.context import get_context
from ..tools.actions import create_action
from ..prompts.system import MEETING_PREP_SYSTEM_PROMPT


async def get_upcoming_external_meetings(
    hours_ahead: int = 24
) -> list[dict[str, Any]]:
    """
    Get calendar events with external attendees in the next N hours.

    Args:
        hours_ahead: How many hours ahead to look.

    Returns:
        List of external meetings.
    """
    # Get today's events
    today = datetime.now().strftime("%Y-%m-%d")
    result = await get_calendar_events(today)

    if "error" in result:
        print(f"Error fetching calendar: {result['error']}")
        return []

    events = result.get("events", [])

    # Filter to external meetings in the time window
    now = datetime.now()
    cutoff = now + timedelta(hours=hours_ahead)

    external_meetings = []
    for event in events:
        # Check if it's external
        if not event.get("is_external", False):
            continue

        # Check if it's in the time window
        try:
            start_str = event.get("start", "")
            # Parse ISO format
            start = datetime.fromisoformat(start_str.replace("Z", "+00:00"))
            start = start.replace(tzinfo=None)  # Make naive for comparison

            if now <= start <= cutoff:
                external_meetings.append(event)
        except (ValueError, TypeError):
            continue

    return external_meetings


async def lookup_attendees(attendees: list[str]) -> dict[str, dict[str, Any]]:
    """
    Look up attendees in the People CRM.

    Args:
        attendees: List of attendee names.

    Returns:
        Dictionary mapping names to their CRM info (or empty dict if not found).
    """
    results = {}

    for name in attendees:
        if not name:
            continue

        result = await lookup_person(name)

        if result.get("found", False) and result.get("people"):
            # Take the first match
            results[name] = result["people"][0]
        else:
            results[name] = {"not_found": True}

    return results


async def generate_meeting_brief(
    event: dict[str, Any],
    attendee_info: dict[str, dict[str, Any]],
    context_info: dict[str, Any],
) -> str:
    """
    Use Claude to generate a meeting brief.

    Args:
        event: Calendar event details.
        attendee_info: CRM info for attendees.
        context_info: Current work context.

    Returns:
        Generated meeting brief markdown.
    """
    config = get_config()
    client = anthropic.Anthropic()

    # Build the prompt
    prompt = f"""Generate a meeting brief for the following event:

## Event Details
- Title: {event.get('title', 'Untitled')}
- Start: {event.get('start', 'Unknown')}
- End: {event.get('end', 'Unknown')}
- Location: {event.get('location', 'Not specified')}
- Calendar: {event.get('calendar', 'Unknown')}

## Attendees
"""

    for name, info in attendee_info.items():
        prompt += f"\n### {name}\n"
        if info.get("not_found"):
            prompt += "- Not in People CRM\n"
        else:
            if info.get("one_liner"):
                prompt += f"- Bio: {info['one_liner']}\n"
            if info.get("organizations"):
                for org in info["organizations"]:
                    role = org.get("role", "")
                    org_name = org.get("name", "Unknown")
                    if role:
                        prompt += f"- Role: {role} at {org_name}\n"
                    else:
                        prompt += f"- Organization: {org_name}\n"
            if info.get("notes"):
                prompt += f"- Notes: {info['notes']}\n"
            if info.get("tags"):
                prompt += f"- Tags: {', '.join(info['tags'])}\n"

    # Add work context if available
    if context_info and not context_info.get("error"):
        active = context_info.get("active_context", {})
        if active:
            prompt += f"""
## Current Work Context
- Session type: {active.get('type', 'unknown')}
- Focus score: {active.get('focus_score', 0):.0%}
- Active apps: {', '.join(active.get('apps', [])[:5])}
"""

    prompt += """

Please generate a comprehensive meeting brief that includes:
1. A summary of who the attendees are
2. Any relevant context or notes about them
3. Suggested talking points based on their background
4. Any preparation suggestions

Format the brief in clean markdown.
"""

    # Call Claude
    message = client.messages.create(
        model=config.agent.model,
        max_tokens=config.agent.max_tokens,
        system=MEETING_PREP_SYSTEM_PROMPT,
        messages=[{"role": "user", "content": prompt}]
    )

    return message.content[0].text


async def prepare_for_meeting(event: dict[str, Any]) -> dict[str, Any]:
    """
    Full workflow to prepare for a single meeting.

    Args:
        event: Calendar event to prepare for.

    Returns:
        Result including the action ID if successful.
    """
    print(f"Preparing for: {event.get('title', 'Untitled')}")

    # 1. Look up attendees
    attendees = event.get("attendees", [])
    print(f"  Looking up {len(attendees)} attendees...")
    attendee_info = await lookup_attendees(attendees)

    # 2. Get work context
    print("  Getting work context...")
    context_info = await get_context()

    # 3. Generate brief using Claude
    print("  Generating meeting brief...")
    brief = await generate_meeting_brief(event, attendee_info, context_info)

    # 4. Submit as action
    print("  Submitting action...")
    result = await create_action(
        type="meeting_brief",
        title=f"Meeting Brief: {event.get('title', 'Untitled')}",
        summary=f"Prepared brief for meeting with {', '.join(attendees[:3])}{'...' if len(attendees) > 3 else ''}",
        draft_content=brief,
        related_event_id=event.get("id"),
        related_event_title=event.get("title"),
    )

    if result.get("success"):
        print(f"  Created action: {result.get('action_id')}")
    else:
        print(f"  Error: {result.get('error')}")

    return result


async def run_meeting_prep(
    date: str | None = None,
    event_id: str | None = None,
    hours_ahead: int = 24,
) -> list[dict[str, Any]]:
    """
    Run meeting prep for upcoming external meetings.

    Args:
        date: Specific date to check (YYYY-MM-DD). Defaults to today.
        event_id: Specific event ID to prepare for.
        hours_ahead: How many hours ahead to look for meetings.

    Returns:
        List of results for each meeting prepared.
    """
    results = []

    if event_id:
        # Prepare for a specific event
        events_result = await get_calendar_events(date or datetime.now().strftime("%Y-%m-%d"))
        events = events_result.get("events", [])
        event = next((e for e in events if e.get("id") == event_id), None)

        if event:
            result = await prepare_for_meeting(event)
            results.append(result)
        else:
            print(f"Event {event_id} not found")
    else:
        # Get all upcoming external meetings
        meetings = await get_upcoming_external_meetings(hours_ahead)

        if not meetings:
            print("No upcoming external meetings found")
            return results

        print(f"Found {len(meetings)} external meetings")

        for meeting in meetings:
            result = await prepare_for_meeting(meeting)
            results.append(result)

    return results


# Entry point for CLI
def main(date: str | None = None, event_id: str | None = None, hours_ahead: int = 24):
    """Synchronous entry point."""
    return asyncio.run(run_meeting_prep(date, event_id, hours_ahead))
