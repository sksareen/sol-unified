"""
Sol Unified Agent CLI

Main entry point for the Claude Agent SDK integration.

Usage:
    python -m agent.sdk.main run "prepare for my 2pm meeting"
    python -m agent.sdk.main meeting-prep --date today
    python -m agent.sdk.main daemon --interval 15
    python -m agent.sdk.main health
"""

import asyncio
import sys
from datetime import datetime

import click
from rich.console import Console
from rich.table import Table

from .config import get_config, reload_config
from .tools.calendar import get_calendar_events
from .tools.context import get_context
from .tools.people import lookup_person
from .workflows.meeting_prep import run_meeting_prep
from .daemon.scheduler import MeetingPrepScheduler

console = Console()


@click.group()
@click.version_option(version="0.1.0", prog_name="sol-agent")
def cli():
    """Sol Unified Agent - Claude Agent SDK Integration"""
    pass


@cli.command()
@click.argument("task")
def run(task: str):
    """
    Run a single agent task.

    Examples:
        sol-agent run "what's on my calendar today"
        sol-agent run "look up John Smith"
        sol-agent run "prepare for my next meeting"
    """
    import anthropic
    from .prompts.system import AGENT_SYSTEM_PROMPT

    config = get_config()
    client = anthropic.Anthropic()

    # Define tools for the agent
    tools = [
        {
            "name": "get_calendar_events",
            "description": "Get calendar events for a specific date",
            "input_schema": {
                "type": "object",
                "properties": {
                    "date": {"type": "string", "description": "Date in YYYY-MM-DD format"}
                },
                "required": []
            }
        },
        {
            "name": "lookup_person",
            "description": "Look up a person in the People CRM",
            "input_schema": {
                "type": "object",
                "properties": {
                    "name": {"type": "string", "description": "Person's name"}
                },
                "required": ["name"]
            }
        },
        {
            "name": "get_context",
            "description": "Get current work context",
            "input_schema": {
                "type": "object",
                "properties": {},
                "required": []
            }
        },
    ]

    messages = [{"role": "user", "content": task}]

    console.print(f"[bold blue]Task:[/bold blue] {task}")
    console.print()

    # Agent loop
    while True:
        response = client.messages.create(
            model=config.agent.model,
            max_tokens=config.agent.max_tokens,
            system=AGENT_SYSTEM_PROMPT,
            tools=tools,
            messages=messages,
        )

        # Process response
        assistant_content = []
        tool_results = []

        for block in response.content:
            if block.type == "text":
                console.print(f"[green]{block.text}[/green]")
                assistant_content.append({"type": "text", "text": block.text})

            elif block.type == "tool_use":
                console.print(f"[dim]Using tool: {block.name}[/dim]")
                assistant_content.append({
                    "type": "tool_use",
                    "id": block.id,
                    "name": block.name,
                    "input": block.input
                })

                # Execute tool
                result = execute_tool(block.name, block.input)
                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": block.id,
                    "content": str(result)
                })

        # Add assistant message
        messages.append({"role": "assistant", "content": assistant_content})

        # If there were tool uses, add results and continue
        if tool_results:
            messages.append({"role": "user", "content": tool_results})
        else:
            # No more tool calls, we're done
            break

        # Safety check
        if response.stop_reason == "end_turn":
            break


def execute_tool(name: str, args: dict) -> dict:
    """Execute a tool and return the result."""
    if name == "get_calendar_events":
        return asyncio.run(get_calendar_events(args.get("date")))
    elif name == "lookup_person":
        return asyncio.run(lookup_person(args.get("name", "")))
    elif name == "get_context":
        return asyncio.run(get_context())
    else:
        return {"error": f"Unknown tool: {name}"}


@cli.command("meeting-prep")
@click.option("--date", default=None, help="Date to check (YYYY-MM-DD). Defaults to today.")
@click.option("--event-id", default=None, help="Specific event ID to prepare for.")
@click.option("--hours-ahead", default=24, help="Hours ahead to look for meetings.")
def meeting_prep(date: str, event_id: str, hours_ahead: int):
    """
    Generate meeting prep briefs for upcoming external meetings.

    Examples:
        sol-agent meeting-prep
        sol-agent meeting-prep --date 2024-01-15
        sol-agent meeting-prep --hours-ahead 4
    """
    console.print("[bold]Running meeting prep...[/bold]")

    results = asyncio.run(run_meeting_prep(
        date=date,
        event_id=event_id,
        hours_ahead=hours_ahead,
    ))

    if not results:
        console.print("[yellow]No meetings prepared[/yellow]")
        return

    console.print(f"\n[green]Prepared {len(results)} meeting brief(s)[/green]")
    for result in results:
        if result.get("success"):
            console.print(f"  - Action ID: {result.get('action_id')}")


@cli.command()
@click.option("--interval", default=None, type=int, help="Check interval in minutes.")
def daemon(interval: int):
    """
    Run background daemon for proactive meeting prep.

    Checks calendar periodically and generates briefs before external meetings.
    """
    console.print("[bold]Starting daemon...[/bold]")
    scheduler = MeetingPrepScheduler()
    asyncio.run(scheduler.run_forever(interval))


@cli.command()
def health():
    """Check connection to Sol Unified."""
    import httpx

    config = get_config()
    url = f"{config.api.sol_unified_url}/health"

    try:
        response = httpx.get(url, timeout=5)
        response.raise_for_status()
        data = response.json()

        console.print("[green]Sol Unified is running[/green]")
        console.print(f"  Status: {data.get('status', 'unknown')}")
        console.print(f"  Requests served: {data.get('uptime_requests', 0)}")

    except httpx.ConnectError:
        console.print("[red]Cannot connect to Sol Unified[/red]")
        console.print(f"  URL: {url}")
        console.print("  Make sure Sol Unified is running")
        sys.exit(1)

    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        sys.exit(1)


@cli.command()
@click.option("--date", default=None, help="Date to check (YYYY-MM-DD)")
def calendar(date: str):
    """Show today's calendar events."""
    if date is None:
        date = datetime.now().strftime("%Y-%m-%d")

    result = asyncio.run(get_calendar_events(date))

    if "error" in result:
        console.print(f"[red]Error: {result['error']}[/red]")
        return

    events = result.get("events", [])

    if not events:
        console.print(f"[yellow]No events for {date}[/yellow]")
        return

    table = Table(title=f"Calendar - {date}")
    table.add_column("Time", style="cyan")
    table.add_column("Title", style="white")
    table.add_column("External", style="yellow")
    table.add_column("Attendees", style="dim")

    for event in events:
        start = event.get("start", "")
        try:
            dt = datetime.fromisoformat(start.replace("Z", "+00:00"))
            time_str = dt.strftime("%I:%M %p")
        except ValueError:
            time_str = start[:16]

        is_external = "Yes" if event.get("is_external") else ""
        attendees = ", ".join(event.get("attendees", [])[:2])
        if len(event.get("attendees", [])) > 2:
            attendees += "..."

        table.add_row(
            time_str,
            event.get("title", "Untitled"),
            is_external,
            attendees,
        )

    console.print(table)


@cli.command()
@click.argument("name")
def lookup(name: str):
    """Look up a person in the People CRM."""
    result = asyncio.run(lookup_person(name))

    if result.get("error"):
        console.print(f"[red]Error: {result['error']}[/red]")
        return

    if not result.get("found", False):
        console.print(f"[yellow]No results for '{name}'[/yellow]")
        return

    for person in result.get("people", []):
        console.print(f"\n[bold]{person.get('name', 'Unknown')}[/bold]")

        if person.get("one_liner"):
            console.print(f"  {person['one_liner']}")

        if person.get("organizations"):
            for org in person["organizations"]:
                role = org.get("role", "")
                org_name = org.get("name", "")
                if role:
                    console.print(f"  [cyan]{role}[/cyan] at [blue]{org_name}[/blue]")
                else:
                    console.print(f"  [blue]{org_name}[/blue]")

        if person.get("email"):
            console.print(f"  Email: {person['email']}")

        if person.get("tags"):
            console.print(f"  Tags: {', '.join(person['tags'])}")

        if person.get("notes"):
            notes = person["notes"][:200] + "..." if len(person.get("notes", "")) > 200 else person["notes"]
            console.print(f"  Notes: [dim]{notes}[/dim]")


@cli.command()
def context():
    """Show current work context."""
    result = asyncio.run(get_context())

    if result.get("error"):
        console.print(f"[red]Error: {result['error']}[/red]")
        return

    active = result.get("active_context", {})

    if active:
        console.print("[bold]Active Context[/bold]")
        console.print(f"  Type: {active.get('type', 'unknown')}")
        console.print(f"  Label: {active.get('label', '')}")
        console.print(f"  Focus: {active.get('focus_score', 0):.0%}")
        console.print(f"  Duration: {active.get('duration_minutes', 0)} min")
        console.print(f"  Apps: {', '.join(active.get('apps', [])[:5])}")
    else:
        console.print("[yellow]No active context[/yellow]")

    # Recent clipboard
    clipboard = result.get("recent_clipboard", [])
    if clipboard:
        console.print("\n[bold]Recent Clipboard[/bold]")
        for item in clipboard[:3]:
            preview = item.get("content_preview", "")[:50]
            app = item.get("source_app", "unknown")
            console.print(f"  [{app}] {preview}...")


@cli.command()
def config():
    """Show current configuration."""
    cfg = get_config()

    console.print("[bold]Configuration[/bold]")
    console.print(f"\n[cyan]API[/cyan]")
    console.print(f"  Sol Unified URL: {cfg.api.sol_unified_url}")
    console.print(f"  Timeout: {cfg.api.timeout_seconds}s")

    console.print(f"\n[cyan]Agent[/cyan]")
    console.print(f"  Model: {cfg.agent.model}")
    console.print(f"  Max tokens: {cfg.agent.max_tokens}")

    console.print(f"\n[cyan]Daemon[/cyan]")
    console.print(f"  Check interval: {cfg.daemon.check_interval_minutes} min")
    console.print(f"  Prep lead time: {cfg.daemon.prep_lead_time_hours} hours")


def main():
    """Main entry point."""
    cli()


if __name__ == "__main__":
    main()
