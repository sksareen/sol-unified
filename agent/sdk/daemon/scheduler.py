"""
Background scheduler for proactive meeting prep.

Runs on a configurable interval, checking for upcoming external meetings
and generating briefs before they start.
"""

import asyncio
import json
from datetime import datetime
from pathlib import Path
from typing import Set

from ..config import get_config
from ..workflows.meeting_prep import get_upcoming_external_meetings, prepare_for_meeting


class MeetingPrepScheduler:
    """
    Scheduler that checks for upcoming meetings and prepares briefs.
    """

    def __init__(self):
        self.config = get_config()
        self.processed_events: Set[str] = set()
        self.state_file = Path.home() / ".config" / "solunified" / "scheduler_state.json"
        self._load_state()

    def _load_state(self):
        """Load processed events from disk."""
        if self.state_file.exists():
            try:
                with open(self.state_file) as f:
                    data = json.load(f)
                    self.processed_events = set(data.get("processed_events", []))
            except (json.JSONDecodeError, IOError):
                self.processed_events = set()

    def _save_state(self):
        """Save processed events to disk."""
        self.state_file.parent.mkdir(parents=True, exist_ok=True)
        with open(self.state_file, "w") as f:
            json.dump({
                "processed_events": list(self.processed_events),
                "last_run": datetime.now().isoformat(),
            }, f)

    def _should_prepare(self, event: dict) -> bool:
        """
        Determine if we should prepare for this meeting.

        Args:
            event: Calendar event dict.

        Returns:
            True if we should prepare a brief.
        """
        event_id = event.get("id", "")

        # Skip if already processed
        if event_id in self.processed_events:
            return False

        # Skip if not external
        if not event.get("is_external", False):
            return False

        # Check timing - prepare within lead_time_hours before the meeting
        try:
            start_str = event.get("start", "")
            start = datetime.fromisoformat(start_str.replace("Z", "+00:00"))
            start = start.replace(tzinfo=None)

            now = datetime.now()
            hours_until = (start - now).total_seconds() / 3600

            # Within prep window and not already started
            if 0 < hours_until <= self.config.daemon.prep_lead_time_hours:
                return True

        except (ValueError, TypeError):
            pass

        return False

    def _mark_processed(self, event: dict):
        """Mark an event as processed."""
        event_id = event.get("id", "")
        if event_id:
            self.processed_events.add(event_id)
            self._save_state()

    async def check_and_prepare(self):
        """
        Main check loop iteration.

        Checks for upcoming meetings and prepares briefs.
        """
        print(f"[{datetime.now().isoformat()}] Checking for meetings...")

        try:
            # Get upcoming external meetings
            meetings = await get_upcoming_external_meetings(
                hours_ahead=self.config.daemon.prep_lead_time_hours
            )

            if not meetings:
                print("  No external meetings in prep window")
                return

            # Filter to ones we should prepare
            to_prepare = [m for m in meetings if self._should_prepare(m)]

            if not to_prepare:
                print("  All meetings already processed")
                return

            print(f"  Found {len(to_prepare)} meetings to prepare")

            # Prepare each (with concurrency limit)
            for meeting in to_prepare[:self.config.daemon.max_concurrent_preps]:
                try:
                    await prepare_for_meeting(meeting)
                    self._mark_processed(meeting)
                except Exception as e:
                    print(f"  Error preparing for {meeting.get('title')}: {e}")

        except Exception as e:
            print(f"  Error in check_and_prepare: {e}")

    async def run_forever(self, interval_minutes: int | None = None):
        """
        Run the scheduler forever.

        Args:
            interval_minutes: Check interval. Defaults to config value.
        """
        interval = interval_minutes or self.config.daemon.check_interval_minutes
        print(f"Starting scheduler (checking every {interval} minutes)")
        print(f"Prep lead time: {self.config.daemon.prep_lead_time_hours} hours")

        while True:
            await self.check_and_prepare()
            await asyncio.sleep(interval * 60)

    def run_once(self):
        """Run a single check (useful for testing)."""
        asyncio.run(self.check_and_prepare())


def main(interval: int | None = None):
    """Entry point for daemon mode."""
    scheduler = MeetingPrepScheduler()
    asyncio.run(scheduler.run_forever(interval))
