import json
import logging
import uuid
from datetime import datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from openai import AsyncOpenAI
from pydantic import ValidationError

logger = logging.getLogger(__name__)

from app.core.config import settings
from app.core.schemas.chat import EventActionsContent, EventAction, EventSnapshot
from app.core.schemas.event import EventCreate, EventUpdate
from app.infrastructure.database.repositories.event_repository import EventRepository


TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "search_events",
            "description": "Search user's calendar events by date range.",
            "parameters": {
                "type": "object",
                "properties": {
                    "start_from": {
                        "type": "string",
                        "description": "ISO-8601 datetime, inclusive lower bound.",
                    },
                    "start_to": {
                        "type": "string",
                        "description": "ISO-8601 datetime, inclusive upper bound.",
                    },
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "create_event",
            "description": "Propose creating a new calendar event. The user must confirm before it is saved.",
            "parameters": {
                "type": "object",
                "properties": {
                    "title": {"type": "string"},
                    "start_at": {"type": "string", "description": "ISO-8601 datetime with timezone offset."},
                    "end_at": {"type": "string", "description": "ISO-8601 datetime. Omit for reminders."},
                    "all_day": {"type": "boolean"},
                    "type": {"type": "string", "enum": ["event", "reminder"]},
                    "description": {"type": "string"},
                    "location": {"type": "string"},
                    "is_fixed": {"type": "boolean"},
                },
                "required": ["title", "start_at"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "update_event",
            "description": "Propose updating an existing event. You MUST call search_events first to get the real event id — never invent an id. Only include fields that should change.",
            "parameters": {
                "type": "object",
                "properties": {
                    "event_id": {"type": "string", "description": "UUID of the event to update."},
                    "title": {"type": "string"},
                    "start_at": {"type": "string"},
                    "end_at": {"type": "string"},
                    "all_day": {"type": "boolean"},
                    "type": {"type": "string", "enum": ["event", "reminder"]},
                    "description": {"type": "string"},
                    "location": {"type": "string"},
                    "is_fixed": {"type": "boolean"},
                },
                "required": ["event_id"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "delete_event",
            "description": "Propose deleting an existing event. You MUST call search_events first to get the real event id — never invent an id.",
            "parameters": {
                "type": "object",
                "properties": {
                    "event_id": {"type": "string", "description": "UUID of the event to delete."},
                },
                "required": ["event_id"],
            },
        },
    },
]

_MUTATION_TOOLS = {"create_event", "update_event", "delete_event"}


class LLMService:

    def __init__(self, client: AsyncOpenAI):
        self.client = client

    async def process_user_message(
        self,
        user_message: str,
        history: list[dict],
        user_id: uuid.UUID,
        user_timezone: str,
        event_repo: EventRepository,
    ) -> tuple[str, list[EventAction]]:
        """
        Обрабатывает сообщение пользователя:
        - выполняет search_events сразу
        - собирает create/update/delete как EventAction (pending, не выполняя)
        Возвращает (text_response, actions).
        """
        try:
            tz = ZoneInfo(user_timezone)
            tz_label = user_timezone
        except ZoneInfoNotFoundError:
            tz = ZoneInfo("UTC")
            tz_label = "UTC"

        system_prompt = self._build_system_prompt(tz, tz_label)
        messages: list[dict] = [{"role": "system", "content": system_prompt}]
        messages.extend(history)
        messages.append({"role": "user", "content": user_message})

        collected_actions: list[EventAction] = []

        for _ in range(6):  # guard against infinite tool-call loops
            response = await self.client.chat.completions.create(
                model=settings.LLM_MODEL,
                messages=messages,
                tools=TOOLS,
                tool_choice="auto",
            )

            choice = response.choices[0]
            assistant_msg = choice.message

            # Добавляем сообщение ассистента в историю
            messages.append(assistant_msg.model_dump(exclude_unset=True, exclude_none=True))

            if not assistant_msg.tool_calls:
                await self._enrich_with_snapshots(collected_actions, user_id, event_repo)
                return assistant_msg.content or "", collected_actions

            # Обрабатываем tool calls
            for tool_call in assistant_msg.tool_calls:
                name = tool_call.function.name
                try:
                    args = json.loads(tool_call.function.arguments)
                except json.JSONDecodeError:
                    args = {}

                if name == "search_events":
                    result = await self._execute_search(args, user_id, event_repo, tz)
                    tool_result = json.dumps(result, ensure_ascii=False, default=str)
                elif name in _MUTATION_TOOLS:
                    action = self._build_action(name, args, tz)
                    if action:
                        collected_actions.append(action)
                        tool_result = "Action queued for user confirmation."
                    else:
                        tool_result = (
                            "Error: could not build action — invalid arguments. "
                            "For update_event and delete_event you must call search_events first "
                            "to obtain the real event UUID, then pass that exact UUID as event_id."
                        )
                else:
                    tool_result = "Unknown tool."

                messages.append({
                    "role": "tool",
                    "tool_call_id": tool_call.id,
                    "content": tool_result,
                })

        return "", collected_actions

    async def _enrich_with_snapshots(
        self,
        actions: list[EventAction],
        user_id: uuid.UUID,
        event_repo: EventRepository,
    ) -> None:
        for action in actions:
            if action.action in ("update", "delete") and action.event_id:
                event = await event_repo.get_by_id(action.event_id, user_id)
                if event:
                    action.event_snapshot = EventSnapshot(
                        title=event.title,
                        start_at=event.start_at,
                        end_at=event.end_at,
                    )

    async def _execute_search(
        self,
        args: dict,
        user_id: uuid.UUID,
        event_repo: EventRepository,
        tz: ZoneInfo | None = None,
    ) -> list[dict]:
        start_from = self._parse_dt_localized(args.get("start_from"), tz)
        start_to = self._parse_dt_localized(args.get("start_to"), tz)
        events = await event_repo.search(user_id, start_from, start_to)
        return [
            {
                "id": str(e.id),
                "title": e.title,
                "description": e.description,
                "start_at": self._to_local_iso(e.start_at, tz),
                "end_at": self._to_local_iso(e.end_at, tz) if e.end_at else None,
                "all_day": e.all_day,
                "type": e.type,
                "location": e.location,
                "is_fixed": e.is_fixed,
            }
            for e in events
        ]

    def _build_action(self, tool_name: str, args: dict, tz: ZoneInfo | None = None) -> EventAction | None:
        original_args = args.copy()
        try:
            if tz is not None:
                args = self._normalize_datetime_args(args, tz)
            if tool_name == "create_event":
                payload = EventCreate(**args, source="ai")
                return EventAction(action="create", payload=payload)
            elif tool_name == "update_event":
                event_id = uuid.UUID(args.pop("event_id"))
                payload = EventUpdate(**args)
                return EventAction(action="update", event_id=event_id, payload=payload)
            elif tool_name == "delete_event":
                event_id = uuid.UUID(args["event_id"])
                return EventAction(action="delete", event_id=event_id)
        except (ValidationError, ValueError, KeyError) as exc:
            logger.warning("Failed to build action %s: %s | args=%s", tool_name, exc, original_args)
            return None

    @staticmethod
    def _normalize_datetime_args(args: dict, tz: ZoneInfo) -> dict:
        """Attach user's timezone to naive datetimes before storing."""
        args = args.copy()
        for field in ("start_at", "end_at"):
            raw = args.get(field)
            if not raw:
                continue
            try:
                dt = datetime.fromisoformat(raw)
                if dt.tzinfo is None:
                    args[field] = dt.replace(tzinfo=tz).isoformat()
            except (ValueError, TypeError):
                pass
        return args

    @staticmethod
    def _parse_dt(value: str | None) -> datetime | None:
        if not value:
            return None
        try:
            return datetime.fromisoformat(value)
        except ValueError:
            return None

    @staticmethod
    def _parse_dt_localized(value: str | None, tz: ZoneInfo | None) -> datetime | None:
        """Parse datetime string; attach user's timezone if naive."""
        if not value:
            return None
        try:
            dt = datetime.fromisoformat(value)
            if dt.tzinfo is None and tz is not None:
                dt = dt.replace(tzinfo=tz)
            return dt
        except ValueError:
            return None

    @staticmethod
    def _to_local_iso(dt: datetime, tz: ZoneInfo | None) -> str:
        """Convert a datetime (possibly UTC from DB) to user's local ISO string."""
        if tz is None:
            return dt.isoformat()
        if dt.tzinfo is None:
            from datetime import timezone as _tz
            dt = dt.replace(tzinfo=_tz.utc)
        return dt.astimezone(tz).isoformat()

    @staticmethod
    def _build_system_prompt(tz: ZoneInfo, tz_label: str) -> str:
        now = datetime.now(tz)
        raw_offset = now.strftime('%z')  # e.g. "+0300" or "-0500"
        utc_offset = f"{raw_offset[:3]}:{raw_offset[3:]}" if len(raw_offset) == 5 else raw_offset
        return (
            f"You are Sentinel, an intelligent time management assistant.\n"
            f"Current date and time: {now.strftime('%A, %Y-%m-%d %H:%M')} ({tz_label}, UTC{utc_offset}).\n"
            f"User's timezone: {tz_label} (UTC{utc_offset}). "
            f"All times the user mentions are in this timezone unless they explicitly specify otherwise. "
            f"Never infer a timezone from a location name or address.\n"
            f"Event times returned by search_events are already in the user's local timezone (UTC{utc_offset}).\n"
            f"In create_event and update_event calls always include the timezone offset in start_at/end_at "
            f"(e.g. 2026-04-20T09:00:00{utc_offset}).\n"
            f"Before calling update_event or delete_event always call search_events first to get the real event id. "
            f"Never guess or invent an event id.\n\n"
            "Help users manage their calendar. Use search_events to look up existing events when needed.\n"
            "When the user asks to schedule something, make reasonable assumptions for any unspecified details "
            "(e.g., default duration 1 hour, skip optional fields) and immediately call create_event to propose the event. "
            "Do not ask clarifying questions before proposing — propose first, the user can adjust afterward.\n"
            "create_event, update_event and delete_event only PROPOSE changes — "
            "they are not applied until the user explicitly confirms.\n"
            "If the user's request is not related to calendar management (e.g., asks to write code, "
            "explain concepts, translate text, etc.), politely decline in the user's language and do not use any tools.\n"
            "Always reply in the same language the user writes in."
        )
