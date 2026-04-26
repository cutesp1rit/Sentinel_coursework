import json
import logging
import uuid
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from openai import AsyncOpenAI

from app.core.config import settings
from app.core.schemas.rebalance import (
    ApplyEventChange,
    ProposedEvent,
    RebalanceApplyRequest,
    RebalanceDay,
    RebalanceRequest,
    RebalanceResponse,
)
from app.infrastructure.database.models import Event
from app.infrastructure.database.repositories.event_repository import EventRepository

logger = logging.getLogger(__name__)


class RebalanceValidationError(Exception):
    pass


class RebalanceService:

    def __init__(self, client: AsyncOpenAI, model: str = ""):
        self.client = client
        self.model = model

    async def propose(
        self,
        user_id: uuid.UUID,
        request: RebalanceRequest,
        event_repo: EventRepository,
    ) -> RebalanceResponse:
        tz = self._parse_timezone(request.timezone)
        day_ranges_utc = self._compute_day_ranges_utc(request.days, tz)

        events = await event_repo.get_events_for_days(user_id, day_ranges_utc)
        events = self._exclude_multiday(events, request.days, tz)

        if not events:
            return RebalanceResponse(
                proposed=[],
                summary="Нет событий для ребалансировки на выбранные дни.",
                changed_count=0,
                unchanged_count=0,
            )

        last_error: Exception | None = None
        for attempt in range(2):
            try:
                llm_output = await self._call_llm(events, request.days, tz, request.user_prompt)
                return self._build_response(events, llm_output, tz)
            except RebalanceValidationError as exc:
                last_error = exc
                logger.warning("Rebalance LLM validation failed (attempt %d): %s", attempt + 1, exc)

        raise RebalanceValidationError(str(last_error))

    async def apply(
        self,
        user_id: uuid.UUID,
        request: RebalanceApplyRequest,
        event_repo: EventRepository,
    ) -> None:
        await self._validate_apply_request(user_id, request.events, event_repo)
        changes = [
            {"id": c.id, "start_at": c.start_at, "end_at": c.end_at}
            for c in request.events
        ]
        await event_repo.bulk_update_times(user_id, changes)

    # --- Internal helpers ---

    @staticmethod
    def _parse_timezone(timezone_str: str) -> ZoneInfo:
        try:
            return ZoneInfo(timezone_str)
        except (ZoneInfoNotFoundError, KeyError):
            return ZoneInfo("UTC")

    @staticmethod
    def _compute_day_ranges_utc(
        days: list[RebalanceDay],
        tz: ZoneInfo,
    ) -> list[tuple[datetime, datetime]]:
        ranges = []
        for day in days:
            start_local = datetime(day.date.year, day.date.month, day.date.day, tzinfo=tz)
            end_local = start_local + timedelta(days=1)
            ranges.append((
                start_local.astimezone(timezone.utc),
                end_local.astimezone(timezone.utc),
            ))
        return ranges

    @staticmethod
    def _exclude_multiday(
        events: list[Event],
        days: list[RebalanceDay],
        tz: ZoneInfo,
    ) -> list[Event]:
        selected_dates = {d.date for d in days}
        result = []
        for event in events:
            if event.end_at is None:
                result.append(event)
                continue
            start_date = event.start_at.astimezone(tz).date()
            end_date = event.end_at.astimezone(tz).date()
            if start_date == end_date:
                result.append(event)
                continue
            # Multi-day event: include only if it spans ALL selected dates
            event_dates = {
                start_date + timedelta(days=i)
                for i in range((end_date - start_date).days + 1)
            }
            if selected_dates.issubset(event_dates):
                result.append(event)
        return result

    @staticmethod
    def _to_local_iso(dt: datetime, tz: ZoneInfo) -> str:
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(tz).isoformat()

    def _events_to_llm_list(self, events: list[Event], tz: ZoneInfo) -> list[dict]:
        result = []
        for e in events:
            is_reminder = e.end_at is None
            item: dict = {
                "id": str(e.id),
                "title": e.title,
                "start_at": self._to_local_iso(e.start_at, tz),
                # Reminders have no duration and should not be rescheduled
                "is_fixed": e.is_fixed or is_reminder,
            }
            if e.end_at:
                item["end_at"] = self._to_local_iso(e.end_at, tz)
            if e.description:
                item["description"] = e.description
            result.append(item)
        return result

    @staticmethod
    def _build_workload_summary(events_json: list[dict], days: list[RebalanceDay]) -> str:
        from collections import defaultdict
        by_day: dict[str, list[dict]] = defaultdict(list)
        for ev in events_json:
            day_key = ev["start_at"][:10]
            by_day[day_key].append(ev)

        lines = []
        for day in days:
            key = str(day.date)
            day_events = by_day.get(key, [])
            movable = sum(1 for e in day_events if not e.get("is_fixed"))

            busy_minutes = 0
            for ev in day_events:
                if ev.get("start_at") and ev.get("end_at"):
                    try:
                        s = datetime.fromisoformat(ev["start_at"])
                        e = datetime.fromisoformat(ev["end_at"])
                        busy_minutes += max(0, int((e - s).total_seconds() / 60))
                    except ValueError:
                        pass

            busy_h = round(busy_minutes / 60, 1)
            free_h = round(max(0, 14 - busy_h), 1)  # 08:00–22:00 = 14h working window
            lines.append(
                f"  {key}: {len(day_events)} events ({movable} movable), "
                f"{busy_h}h busy, {free_h}h free"
            )

        return "\n".join(lines)

    @staticmethod
    def _build_prompt(
        events_json: list[dict],
        days: list[RebalanceDay],
        tz: ZoneInfo,
        user_prompt: str | None = None,
    ) -> str:
        now = datetime.now(tz)
        raw_offset = now.strftime("%z")
        utc_offset = f"{raw_offset[:3]}:{raw_offset[3:]}" if len(raw_offset) == 5 else raw_offset

        battery_lines = []
        for day in days:
            if day.resource_battery is not None:
                pct = int(day.resource_battery * 100)
                battery_lines.append(f"  - {day.date}: {pct}% energy")
        battery_section = ""
        if battery_lines:
            battery_section = (
                "\n\nUser's energy levels (Resource Battery) for each day:\n"
                + "\n".join(battery_lines)
                + "\n0% = exhausted, 100% = full energy. Schedule demanding tasks when energy is higher."
            )

        days_str = ", ".join(str(d.date) for d in days)
        events_str = json.dumps(events_json, ensure_ascii=False, indent=2)
        workload = RebalanceService._build_workload_summary(events_json, days)

        return (
            f"You are a personal schedule optimizer. The user's timezone is UTC{utc_offset}.\n"
            f"All times are already in the user's local time (UTC{utc_offset}).\n\n"
            f"The user selected {len(days)} day(s) to rebalance: {days_str}.{battery_section}\n\n"
            "## Current workload\n"
            f"{workload}\n\n"
            "## Your task\n"
            "Balance the workload across the selected days so that busy hours are roughly equal. "
            "If one day is significantly more loaded, move only enough events to bring it closer "
            "to the level of other days — not all of them. The goal is an even distribution, "
            "not to empty one day and fill another. "
            "If days are already roughly balanced, make minimal or no changes. "
            "Prefer keeping events on their original day unless moving clearly improves the balance.\n\n"
            "## Events\n"
            f"{events_str}\n\n"
            + (
                "## User's personal request (highest priority)\n"
                f"{user_prompt}\n"
                "Respect this request above all else. It overrides the general balancing goal "
                "if they conflict — the user knows their schedule best.\n\n"
                if user_prompt else ""
            ) +
            "## Constraints\n"
            "1. is_fixed=true events must keep their exact start_at and end_at — do not touch them.\n"
            "2. is_fixed=false events can be placed on any of the selected days at any time.\n"
            "3. Events must not overlap. Leave at least 10 minutes between them.\n"
            "4. Only schedule within 08:00–22:00 local time.\n"
            "5. If resource_battery is given for a day, avoid heavy tasks when energy is low.\n"
            "6. Respect the natural time of day for each event. "
            "A lunch or meal event belongs around midday, a workout in the morning or evening, "
            "a work task during working hours. When moving an event to another day, "
            "try to keep it at roughly the same time of day as originally scheduled. "
            "Do not blindly pack events starting from 08:00 — spread them naturally.\n\n"
            "## Response\n"
            "Return every event — including unchanged ones. Use the same start_at/end_at for events you did not move.\n\n"
            "Return ONLY valid JSON:\n"
            "{\n"
            '  "events": [\n'
            '    {"id": "<uuid>", "start_at": "<ISO-8601 with offset>", "end_at": "<ISO-8601 with offset or null>"}\n'
            "  ],\n"
            '  "summary": "<brief explanation in Russian of what changed and why>"\n'
            "}"
        )

    async def _call_llm(
        self,
        events: list[Event],
        days: list[RebalanceDay],
        tz: ZoneInfo,
        user_prompt: str | None = None,
    ) -> dict:
        events_json = self._events_to_llm_list(events, tz)
        prompt = self._build_prompt(events_json, days, tz, user_prompt)

        logger.debug("rebalance_llm_prompt:\n%s", prompt)

        response = await self.client.chat.completions.create(
            model=self.model or settings.LLM_MODEL,
            messages=[{"role": "user", "content": prompt}],
            response_format={"type": "json_object"},
            max_tokens=2048,
        )

        raw = response.choices[0].message.content or ""
        logger.debug("rebalance_llm_response:\n%s", raw)

        try:
            return json.loads(raw)
        except json.JSONDecodeError as exc:
            raise RebalanceValidationError(f"LLM returned invalid JSON: {exc}") from exc

    def _build_response(
        self,
        original_events: list[Event],
        llm_output: dict,
        tz: ZoneInfo,
    ) -> RebalanceResponse:
        llm_events: list[dict] = llm_output.get("events", [])
        summary: str = llm_output.get("summary", "")

        if not isinstance(llm_events, list):
            raise RebalanceValidationError("LLM response 'events' is not a list")
        if not isinstance(summary, str):
            raise RebalanceValidationError("LLM response 'summary' is not a string")

        original_by_id = {str(e.id): e for e in original_events}
        self._validate_llm_events(llm_events, original_by_id)

        proposed: list[ProposedEvent] = []
        changed_count = 0

        for item in llm_events:
            event_id = item["id"]
            original = original_by_id[event_id]

            new_start = self._parse_local_dt(item["start_at"], tz)
            # Reminders have no end_at — ignore whatever the model returned
            if original.end_at is None:
                new_end = None
            else:
                new_end = self._parse_local_dt(item.get("end_at"), tz) if item.get("end_at") else None

            orig_start = self._ensure_tz(original.start_at)
            orig_end = self._ensure_tz(original.end_at) if original.end_at else None

            changed = (new_start != orig_start) or (new_end != orig_end)
            if changed:
                changed_count += 1

            proposed.append(ProposedEvent(
                id=original.id,
                title=original.title,
                start_at=new_start,
                end_at=new_end,
                original_start_at=orig_start,
                original_end_at=orig_end,
                changed=changed,
            ))

        return RebalanceResponse(
            proposed=proposed,
            summary=summary,
            changed_count=changed_count,
            unchanged_count=len(proposed) - changed_count,
        )

    def _validate_llm_events(
        self,
        llm_events: list[dict],
        original_by_id: dict[str, Event],
    ) -> None:
        # All original IDs must be present
        returned_ids = set()
        for item in llm_events:
            if not isinstance(item, dict) or "id" not in item:
                raise RebalanceValidationError("Each event in LLM response must have 'id'")
            returned_ids.add(item["id"])

        missing = set(original_by_id.keys()) - returned_ids
        if missing:
            raise RebalanceValidationError(f"LLM dropped events: {missing}")

        # Fixed events must not be moved
        for item in llm_events:
            original = original_by_id.get(item["id"])
            if original is None:
                raise RebalanceValidationError(f"LLM returned unknown event id: {item['id']}")
            if original.is_fixed:
                orig_start_iso = original.start_at.isoformat()
                if item.get("start_at") and item["start_at"] != orig_start_iso:
                    # Parse both to compare properly
                    try:
                        llm_start = datetime.fromisoformat(item["start_at"])
                        orig_start = self._ensure_tz(original.start_at)
                        if llm_start.utctimetuple() != orig_start.utctimetuple():
                            raise RebalanceValidationError(
                                f"LLM moved fixed event {item['id']}"
                            )
                    except ValueError:
                        raise RebalanceValidationError(
                            f"Invalid datetime for event {item['id']}: {item['start_at']}"
                        )

        # start_at < end_at (only for events that originally had end_at)
        for item in llm_events:
            original = original_by_id.get(item["id"])
            if original and original.end_at is None:
                # reminder — model may echo end_at=start_at, ignore it
                continue
            start_str = item.get("start_at")
            end_str = item.get("end_at")
            if start_str and end_str:
                try:
                    start = datetime.fromisoformat(start_str)
                    end = datetime.fromisoformat(end_str)
                    if end <= start:
                        raise RebalanceValidationError(
                            f"end_at must be after start_at for event {item['id']}"
                        )
                except ValueError as exc:
                    raise RebalanceValidationError(str(exc)) from exc

        # No overlaps (events with both start and end)
        timed = []
        for item in llm_events:
            if item.get("start_at") and item.get("end_at"):
                try:
                    timed.append((
                        datetime.fromisoformat(item["start_at"]),
                        datetime.fromisoformat(item["end_at"]),
                        item["id"],
                    ))
                except ValueError:
                    pass

        timed.sort(key=lambda x: x[0])
        for i in range(len(timed) - 1):
            _, end_a, id_a = timed[i]
            start_b, _, id_b = timed[i + 1]
            if end_a > start_b:
                raise RebalanceValidationError(
                    f"Events overlap: {id_a} ends at {end_a}, {id_b} starts at {start_b}"
                )

    async def _validate_apply_request(
        self,
        user_id: uuid.UUID,
        changes: list[ApplyEventChange],
        event_repo: EventRepository,
    ) -> None:
        for change in changes:
            event = await event_repo.get_by_id(change.id, user_id)
            if not event:
                raise ValueError(f"Event {change.id} not found")
            if event.is_fixed:
                orig_start = self._ensure_tz(event.start_at)
                new_start = change.start_at
                if new_start.tzinfo is None:
                    new_start = new_start.replace(tzinfo=timezone.utc)
                if orig_start != new_start.astimezone(timezone.utc):
                    raise ValueError(f"Event {change.id} is fixed and cannot be moved")
            if change.end_at is not None and change.end_at <= change.start_at:
                raise ValueError(f"end_at must be after start_at for event {change.id}")

    @staticmethod
    def _parse_local_dt(value: str | None, tz: ZoneInfo) -> datetime | None:
        if not value:
            return None
        dt = datetime.fromisoformat(value)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=tz)
        return dt.astimezone(timezone.utc)

    @staticmethod
    def _ensure_tz(dt: datetime | None) -> datetime | None:
        if dt is None:
            return None
        if dt.tzinfo is None:
            return dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc)
