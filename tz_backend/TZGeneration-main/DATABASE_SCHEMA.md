# Схема базы данных Sentinel Backend (минимальная модель: 5 таблиц)

Документ описывает минимальную, но полноценную схему БД под диалоговый планировщик с LLM tool-use. Схема оптимизирована под запросы вида «у меня уже стрижка на неделе, когда?» без версионности расписаний, без таймблоков и без resource battery. Все необходимые ссылки в плане: [TZGeneration-main/BACKEND_TZ_PLAN.md](TZGeneration-main/BACKEND_TZ_PLAN.md).

Состав таблиц (v1):
- users — профиль и базовые предпочтения
- chats — чат-сессии
- chat_messages — сообщения чатов (включая tool-calls)
- events — события и напоминания (унифицировано)
- user_achievements — достижения пользователя

Конвенции
- Идентификаторы: UUID (gen_random_uuid()).
- Время: TIMESTAMPTZ (UTC) + обязательная нормализация по users.timezone на уровне сервиса.
- Нотации статусов и enum — текстовые перечисления (для простоты миграций), при необходимости можно заменить на Postgres ENUM.

Зависимости PostgreSQL
- Расширения:
  - pgcrypto или uuid-ossp (для UUID, если не используете gen_random_uuid() из pgcrypto)
  - pg_trgm (не обязательно, для ускоренного ILIKE/поиска)
  - (опционально) unaccent и FTS для продвинутого поиска.

---

## 1. Таблица users — профиль пользователя и базовые настройки

Назначение: учетная запись, TZ/локаль, упрощённые предпочтения.

Поля:
- id UUID PK
- email VARCHAR(255) UNIQUE NOT NULL
- password_hash VARCHAR(255) NOT NULL
- full_name VARCHAR(255) NULL
- timezone VARCHAR(50) NOT NULL DEFAULT 'UTC' — IANA (например, 'Europe/Moscow')
- locale VARCHAR(10) NOT NULL DEFAULT 'ru'
- preferences JSONB NULL — компактные индивидуальные настройки (ключи: calendar_connected, calendar_provider и т.п.)
- is_active BOOLEAN NOT NULL DEFAULT TRUE
- is_verified BOOLEAN NOT NULL DEFAULT FALSE
- created_at TIMESTAMPTZ NOT NULL DEFAULT now()
- updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
- last_login_at TIMESTAMPTZ NULL

Рекомендованные индексы:
- UNIQUE(email)
- created_at DESC

DDL (пример):
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  full_name VARCHAR(255),
  timezone VARCHAR(50) NOT NULL DEFAULT 'UTC',
  locale VARCHAR(10) NOT NULL DEFAULT 'ru',
  preferences JSONB,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  is_verified BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_login_at TIMESTAMPTZ
);
CREATE INDEX idx_users_created_at ON users(created_at DESC);
```

---

## 2. Таблица chats — чат-сессии

Назначение: группировать диалоги, чтобы не смешивать контексты.

Поля:
- id UUID PK
- user_id UUID NOT NULL FK → users(id) ON DELETE CASCADE
- title VARCHAR(255) NULL — удобочитаемое название (для UI)
- purpose VARCHAR(30) NOT NULL DEFAULT 'general' — семантика чата: general/planner/support (текстовый enum)
- last_message_at TIMESTAMPTZ NULL
- is_archived BOOLEAN NOT NULL DEFAULT FALSE
- created_at TIMESTAMPTZ NOT NULL DEFAULT now()
- updated_at TIMESTAMPTZ NOT NULL DEFAULT now()

Индексы:
- user_id, last_message_at DESC — быстрый список активных чатов

DDL:
```sql
CREATE TABLE chats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(255),
  purpose VARCHAR(30) NOT NULL DEFAULT 'general',
  last_message_at TIMESTAMPTZ,
  is_archived BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_chats_user_last ON chats(user_id, last_message_at DESC);
```

---

## 3. Таблица chat_messages — сообщения (+журнал tool-use)

Назначение: хранить историю диалога, включая вызовы инструментов.

Поля:
- id UUID PK
- chat_id UUID NOT NULL FK → chats(id) ON DELETE CASCADE
- role VARCHAR(20) NOT NULL — 'user' | 'assistant' | 'tool' | 'system'
- content_text TEXT NULL — каноничный текст
- content_json JSONB NULL — структурированный payload (кнопки, карточки и пр.)
- tool_name TEXT NULL — если роль tool или ответ на tool-call
- tool_args JSONB NULL — аргументы вызова инструмента
- tool_result JSONB NULL — результат выполнения инструмента
- ai_provider VARCHAR(50) NULL, ai_model VARCHAR(100) NULL
- token_usage_prompt INT NULL, token_usage_completion INT NULL
- reply_to_message_id UUID NULL FK → chat_messages(id) ON DELETE SET NULL
- created_at TIMESTAMPTZ NOT NULL DEFAULT now()

Индексы:
- chat_id, created_at — для хронологического вывода
- chat_id, role — быстрый выбор последних ответов ассистента/инструмента

DDL:
```sql
CREATE TABLE chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
  role VARCHAR(20) NOT NULL,
  content_text TEXT,
  content_json JSONB,
  tool_name TEXT,
  tool_args JSONB,
  tool_result JSONB,
  ai_provider VARCHAR(50),
  ai_model VARCHAR(100),
  token_usage_prompt INT,
  token_usage_completion INT,
  reply_to_message_id UUID REFERENCES chat_messages(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_chat_messages_chat_time ON chat_messages(chat_id, created_at);
CREATE INDEX idx_chat_messages_chat_role ON chat_messages(chat_id, role);
```

---

## 4. Таблица events — события и напоминания

Назначение: единая сущность для календарных записей. Напоминание = событие без конца (end_at NULL) или с нулевой длительностью.

Поля:
- id UUID PK
- user_id UUID NOT NULL FK → users(id) ON DELETE CASCADE
- title VARCHAR(500) NOT NULL
- description TEXT NULL
- start_at TIMESTAMPTZ NOT NULL
- end_at TIMESTAMPTZ NULL — если NULL/равно start_at, трактуем как reminder
- all_day BOOLEAN NOT NULL DEFAULT FALSE
- type VARCHAR(20) NOT NULL DEFAULT 'event' — 'event' | 'reminder'
- location VARCHAR(255) NULL
- status VARCHAR(20) NOT NULL DEFAULT 'scheduled' — 'scheduled' | 'done' | 'cancelled'
- source VARCHAR(20) NOT NULL DEFAULT 'user' — 'user' | 'llm' | 'import'
- created_via VARCHAR(20) NOT NULL DEFAULT 'chat' — 'chat' | 'ui' | 'api'
- recurrence_rule VARCHAR(255) NULL — RRULE (по необходимости)
- parent_event_id UUID NULL FK → events(id) ON DELETE CASCADE — исключения серии
- tags TEXT[] NULL
- created_at TIMESTAMPTZ NOT NULL DEFAULT now()
- updated_at TIMESTAMPTZ NOT NULL DEFAULT now()

Ограничения:
- end_at > start_at, если end_at не NULL

Индексы:
- user_id, start_at — основной для выборок по времени
- (опционально) GIN(tags)
- (опционально) FTS/pg_trgm по title/description

DDL:
```sql
CREATE TABLE events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(500) NOT NULL,
  description TEXT,
  start_at TIMESTAMPTZ NOT NULL,
  end_at TIMESTAMPTZ,
  all_day BOOLEAN NOT NULL DEFAULT FALSE,
  type VARCHAR(20) NOT NULL DEFAULT 'event',
  location VARCHAR(255),
  status VARCHAR(20) NOT NULL DEFAULT 'scheduled',
  source VARCHAR(20) NOT NULL DEFAULT 'user',
  created_via VARCHAR(20) NOT NULL DEFAULT 'chat',
  recurrence_rule VARCHAR(255),
  parent_event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  tags TEXT[],
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_events_time CHECK (end_at IS NULL OR end_at > start_at)
);
CREATE INDEX idx_events_user_start ON events(user_id, start_at);
-- Опционально:
-- CREATE INDEX idx_events_tags ON events USING GIN(tags);
-- CREATE INDEX idx_events_title_trgm ON events USING GIN (title gin_trgm_ops);
```

Поиск «стрижки на неделе» (пример запроса сервиса):
```sql
-- Псевдопараметры: :user_id, :start_week, :end_week, :q
SELECT id, title, start_at, end_at, type, location, source
FROM events
WHERE user_id = :user_id
  AND start_at >= :start_week
  AND start_at <  :end_week
  AND (
    title ILIKE '%' || :q || '%'
    OR description ILIKE '%' || :q || '%'
  )
ORDER BY start_at ASC
LIMIT 50;
```

---

## 5. Таблица user_achievements — достижения

Назначение: геймификация и фиксация значимых паттернов.

Поля:
- id UUID PK
- user_id UUID NOT NULL FK → users(id) ON DELETE CASCADE
- achievement_code VARCHAR(100) NOT NULL — уникальный код (набором правил)
- title VARCHAR(255) NOT NULL
- description TEXT NULL
- level INT NOT NULL DEFAULT 1
- points INT NOT NULL DEFAULT 0
- earned_at TIMESTAMPTZ NOT NULL DEFAULT now()
- metadata JSONB NULL — параметры правила/метрики

Ограничения/индексы:
- UNIQUE(user_id, achievement_code, level)
- user_id, earned_at DESC

DDL:
```sql
CREATE TABLE user_achievements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  achievement_code VARCHAR(100) NOT NULL,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  level INT NOT NULL DEFAULT 1,
  points INT NOT NULL DEFAULT 0,
  earned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  metadata JSONB,
  CONSTRAINT uq_achv_user_code_level UNIQUE (user_id, achievement_code, level)
);
CREATE INDEX idx_achv_user_earned ON user_achievements(user_id, earned_at DESC);
```

---

## 6. Инструменты LLM (tool-use) → маппинг на запросы

Инструмент calendar.search_events(args):
- Вход:
  - user_timezone (string, IANA)
  - range (enum: today, tomorrow, this_week, next_week) или custom {start, end} (ISO-8601)
  - query (string, опц.)
  - include_types (array: event, reminder, опц.)
  - limit (int, опц., default 20)
- Логика сервиса:
  1) Превратить range в [start, end] с учётом users.timezone.
  2) Сформировать запрос к events (см. пример SQL выше).
  3) Сконвертировать timestamptz в ISO-8601 для ответа инструмента.
- Ответ:
  - items[]: {id, type, title, start_at, end_at, location, source}
  - summary: текстовая сводка («найдено 2 события на этой неделе»).

Инструмент events.create(args) — опционально (после валидации):
- Вход: title, start_at, end_at(опц.), type(event/reminder), location(опц.)
- Действие: вставка в events со source='llm', created_via='chat'.
- Ответ: созданное событие (id, title, start_at, ...).

Примечание по chit-chat:
- Если запрос не требует доступа к данным (например, «привет, как дела?»), инструменты не вызываются.

---

## 7. Производительность и индексация

- Основной путь — индексы user_id + start_at в events. Это покрывает все диапазонные поиски.
- Для текста — ILIKE по title/description; при росте данных использовать pg_trgm/FTS.
- В chat_messages — индекс (chat_id, created_at) обеспечивает тайм-линию.
- В chats — (user_id, last_message_at) обеспечивает последние активные ветки.

---

## 8. Безопасность и приватность

- Пароли — только в виде безопасного хеша (bcrypt/argon2).
- JWT — хранение секретов в окружении/secret-store.
- Логи и tool_args/tool_result — не сохранять избыточно PII (минимизация данных).
- Все даты/время — в разрезе TZ пользователя только на уровне представления; в БД — UTC.

---

## 9. Миграции и расширение

- Если появятся «черновики задач» до превращения в событие — добавить таблицу tasks (связь 1:N с users).
- Нужна история версий расписаний — добавить schedules и, при необходимости, blocks.
- Появится Vision/файлы — добавить attachments (S3/облако).
- Расширится набор настроек — вынести preferences в отдельную settings при необходимости.

---

## 10. Мини-проверка сценария «у меня стрижка на неделе, когда?»

1) Модель классифицирует запрос как «нужно обратиться к данным».
2) Вызывает calendar.search_events с range=this_week, query="стрижка".
3) Сервис переводит «эта неделя» по users.timezone в [start, end] и выполняет SELECT по events.
4) Возвращает найденные события. Модель формирует естественный ответ пользователю.

Документ согласован с планом: [TZGeneration-main/BACKEND_TZ_PLAN.md](TZGeneration-main/BACKEND_TZ_PLAN.md).