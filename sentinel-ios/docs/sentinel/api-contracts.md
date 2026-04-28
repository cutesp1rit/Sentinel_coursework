# Sentinel API Contracts Summary For iOS

## Global contract rules

- transport: HTTPS + JSON UTF-8
- auth for protected endpoints: `Authorization: Bearer <token>`
- versioning: `/api/v1`
- contract documentation: OpenAPI 3.x
- timestamps: ISO-8601
- user time zone: IANA-based handling
- response localization: assistant text defaults to Russian; system fields and contracts stay in English
- API should keep minor-release backward compatibility

## Entities worth modeling

### User
- unique identity
- email
- credentials
- locale
- IANA time zone
- preferences
- registration and last-login timestamps

### Event / Reminder
- id
- user link
- title
- description
- start_at
- end_at optional
- all_day
- type: event | reminder
- location optional
- status
- source of creation: user | ai | import
- creation mode: chat | interface | api
- tags
- created_at
- updated_at

### Chat
- id
- user link
- title
- purpose
- last message timestamp
- archived flag
- created_at
- updated_at

### Chat message
- id
- chat link
- role: user | assistant | tool | system
- text content
- structured content
- tool call data: name, arguments, result
- AI provider and model metadata
- created_at

### Achievement
- id
- user link
- achievement code
- title
- description
- level
- points
- earned_at
- metadata

## Endpoints

### Auth
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/verify-email`
- `POST /api/v1/auth/resend-verification`
- `POST /api/v1/auth/forgot-password`
- `POST /api/v1/auth/reset-password`
- `GET /api/v1/auth/me`
- `PATCH /api/v1/auth/me`
- `DELETE /api/v1/auth/me`

Notes:
- login issues JWT
- protected endpoints require bearer token
- login requires a verified email
- register accepts `timezone`

### Chats
- `GET /api/v1/chats`
- `POST /api/v1/chats`
- `GET /api/v1/chats/{id}/messages`
- `DELETE /api/v1/chats/{id}`
- `POST /api/v1/chats/{id}/messages`
- `POST /api/v1/chats/{id}/messages/{message_id}/apply`
- `POST /api/v1/chats/{id}/upload`

### LLM Orchestration
- `POST /api/v1/chats/{id}/messages`

Notes:
- user messages are persisted, then the backend invokes the LLM and stores the assistant reply
- assistant replies may contain `content_structured.type = "event_actions"`
- event actions are only proposals until the client calls the `apply` endpoint
- chat history is persisted
- upload currently covers image attachments only

### Events
- `GET /api/v1/events?date_from=...&date_to=...`
- `GET /api/v1/events/{id}`
- `POST /api/v1/events`
- `PATCH /api/v1/events/{id}`
- `DELETE /api/v1/events/{id}`
- `POST /api/v1/events/sync`
- `POST /api/v1/events/rebalance`
- `POST /api/v1/events/rebalance/apply`

Search notes:
- response may include `items[]`
- query parameters are explicit ISO-8601 bounds
- `POST /events` supports `X-Idempotency-Key`

### Achievements
- `GET /api/v1/achievements`

### System
- `GET /api/v1/health`

## Event creation payload expectations

### General event-related input fields
- title
- start_at
- end_at optional
- all_day
- type: event | reminder
- location optional
- tags optional

### LLM-to-backend structured payload
When an assistant-confirmed creation happens, the LLM side should form a validated structured JSON payload.

Expected format:
- file concept: `event_payload.json`
- content type: `application/json; charset=utf-8`
- can be passed as structured tool output or a clearly isolatable text block
- permanent file storage is not required; data can be processed on the fly

Required fields:
- `title`: non-empty string
- `start_at`: ISO-8601 string with user time zone
- `type`: `event` or `reminder`
- `all_day`: boolean

Optional fields:
- `end_at`: ISO-8601 string, must be strictly greater than `start_at` if present
- `location`: string
- `tags`: array of strings
- `source`: string, default `llm`

## Output and error conventions

### Search and list outputs
- JSON format
- HTTP status codes should follow normal semantics
- IDs are UUID strings

### Chat outputs
- chronological messages
- message roles can be user, assistant, tool, system
- technical metadata may be present
- assistant message `content_structured` may contain proposed `create`, `update`, or `delete` event actions
- apply response returns the updated assistant message with accepted and rejected statuses

### Error shape
- `{code, message, details}`

## Storage and backend assumptions that affect iOS

- PostgreSQL 14+
- UUID identifiers
- TIMESTAMPTZ in UTC
- tables: users, chats, chat_messages, events, user_achievements
- important indexes include:
  - users(email) UNIQUE
  - events(user_id, start_at)
  - chat_messages(chat_id, created_at)

## Practical iOS implications

- model auth state separately from content state
- keep server event identity distinct from EventKit identity
- treat reminders as event-like entities with missing end time semantics
- handle optional fields carefully, especially `end_at`, `location`, and `tags`
- keep all date conversions explicit and time-zone aware
- expect chat responses to mix plain text with structured tool-driven payloads
- preserve deduplication strategy when exporting to EventKit
- account deletion is now exposed through `DELETE /auth/me`
- profile-level AI instructions are now exposed through `PATCH /auth/me`
- attachment upload is currently image-only via `POST /chats/{id}/upload`
