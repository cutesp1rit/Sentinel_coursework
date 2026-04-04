import json
import uuid
from datetime import datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from openai import AsyncOpenAI
from pydantic import ValidationError

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
            "description": "Propose updating an existing event. Only include fields that should change.",
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
            "description": "Propose deleting an existing event.",
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
        system_prompt = self._build_system_prompt(user_timezone)
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
                    result = await self._execute_search(args, user_id, event_repo)
                    tool_result = json.dumps(result, ensure_ascii=False, default=str)
                elif name in _MUTATION_TOOLS:
                    action = self._build_action(name, args)
                    if action:
                        collected_actions.append(action)
                    tool_result = "Action queued for user confirmation."
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
    ) -> list[dict]:
        start_from = self._parse_dt(args.get("start_from"))
        start_to = self._parse_dt(args.get("start_to"))
        events = await event_repo.search(user_id, start_from, start_to)
        return [
            {
                "id": str(e.id),
                "title": e.title,
                "description": e.description,
                "start_at": e.start_at.isoformat(),
                "end_at": e.end_at.isoformat() if e.end_at else None,
                "all_day": e.all_day,
                "type": e.type,
                "location": e.location,
                "is_fixed": e.is_fixed,
            }
            for e in events
        ]

    def _build_action(self, tool_name: str, args: dict) -> EventAction | None:
        try:
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
        except (ValidationError, ValueError, KeyError):
            return None

    @staticmethod
    def _parse_dt(value: str | None) -> datetime | None:
        if not value:
            return None
        try:
            return datetime.fromisoformat(value)
        except ValueError:
            return None

    @staticmethod
    def _build_system_prompt(timezone: str) -> str:
        try:
            tz = ZoneInfo(timezone)
            tz_label = timezone
        except ZoneInfoNotFoundError:
            tz = ZoneInfo("UTC")
            tz_label = "UTC"
        now = datetime.now(tz)
        return (
            f"You are Sentinel, an intelligent time management assistant.\n"
            f"Current date and time: {now.strftime('%Y-%m-%d %H:%M')} ({tz_label}).\n"
            f"User's timezone: {tz_label}. All times the user mentions are in this timezone unless they explicitly specify otherwise. "
            f"Never infer a timezone from a location name or address.\n\n"
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
