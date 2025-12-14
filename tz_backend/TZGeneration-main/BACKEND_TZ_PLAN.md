 # Инструкция‑план по подготовке ТЗ (Backend) для проекта «Sentinel — AI Scheduler»

Цель документа: дать пошаговый backend‑план, что и где писать в шаблоне ТЗ, и как реализуем серверную часть. В этом выпуске отражена упрощенная модель данных (5 таблиц) и использование LLM tool‑use для доступа к данным.

Размещение материалов
- План (этот файл): [TZGeneration-main/BACKEND_TZ_PLAN.md](TZGeneration-main/BACKEND_TZ_PLAN.md)
- Схема БД (детально): [TZGeneration-main/DATABASE_SCHEMA.md](TZGeneration-main/DATABASE_SCHEMA.md)
- Точка входа ТЗ: [TZGeneration-main/ТЗ/main.typ](TZGeneration-main/ТЗ/main.typ)
- Данные ТЗ: [TZGeneration-main/ТЗ/data.typ](TZGeneration-main/ТЗ/data.typ)
- Текст ТЗ: [TZGeneration-main/ТЗ/body.typ](TZGeneration-main/ТЗ/body.typ)
- Шаблон: [TZGeneration-main/ТЗ/template.typ](TZGeneration-main/ТЗ/template.typ), [TZGeneration-main/ТЗ/cfg.typ](TZGeneration-main/ТЗ/cfg.typ)

## 1. Границы и ответственность backend
- Язык/фреймворк: Python 3.11+, FastAPI (ASGI: Uvicorn/Gunicorn)
- Хранилище: PostgreSQL 14+
- LLM-интеграция: OpenAI SDK (function calling/tool‑use). Своих моделей нет
- Логика: нормализация запросов пользователя, поиск по событиям (events), ведение чат‑сессий, ачивки
- Безопасность: JWT, HTTPS, хранение PII в БД, секреты в env/secret store
- Документация: OpenAPI 3.x, README для деплоя, ПМИ (ГОСТ 19.301‑79)
- Деплой: Docker, dev/prod конфиг, наблюдаемость (логи, метрики)

## 2. Архитектура решения (обзор)
Поток: клиент → /api/llm/chat → LLM (с описанием инструментов) → [tool‑call] → backend сервис (поиск событий/задач) → ответ модели → клиент.

Компоненты:
- API‑слой FastAPI: auth, chat, events, achievements
- LLM‑прокси: единый эндпоинт/оркестратор tool‑use
- Доступ к данным: репозитории поверх PostgreSQL
- Сервис домена: нормализация времени/таймзоны, парсинг запросов, проверки прав
- Интеграции (по мере необходимости): календарные провайдеры

## 2.1 Технический стек (зафиксировано)
- ORM/доступ к БД: SQLAlchemy 2.0 (async) + драйвер asyncpg
- Миграции: Alembic
- Схемы и валидация: Pydantic v2
- LLM‑клиент: OpenAI SDK (function calling/tool‑use)
- Сервер: FastAPI + Uvicorn/Gunicorn
- Тесты: pytest, pytest-asyncio, httpx

Примечание: на старте не используем Redis/кэш и устойчивостные библиотеки; при росте нагрузки можно добавить их без изменения публичных контрактов.

## 3. Доменные сущности (минимальная модель, 5 таблиц)
Полные схемы и индексы описаны в [TZGeneration-main/DATABASE_SCHEMA.md](TZGeneration-main/DATABASE_SCHEMA.md).

- users — профиль пользователя и базовые предпочтения
  - Ключевые поля: id, email (unique), password_hash, full_name, timezone (IANA), locale, preferences(JSONB), created_at/updated_at/last_login_at
  - Для небольших объемов настроек используем preferences внутри users (отдельной таблицы settings нет)

- chats — чат‑сессии на пользователя
  - Поля: id, user_id, title, purpose(enum), last_message_at, is_archived, created_at/updated_at
  - Нужны для раздельных контекстов диалогов (не смешивать темы)

- chat_messages — сообщения в рамках чата (+возможность журналировать tool‑use)
  - Поля: id, chat_id, role(enum: user/assistant/tool/system), content_text, content_json(JSONB), tool_name/tool_args/tool_result (опц.), ai_provider/ai_model, token_usage_*, created_at

- events — унифицированные «событие/напоминание»
  - Поля: id, user_id, title, description, start_at, end_at(NULL для напоминаний), all_day, type(enum: event/reminder), location, status(enum), source(enum: user/llm/import), created_via(enum: chat/ui/api), recurrence_rule (опц.), parent_event_id (опц.), tags(TEXT[]), created_at/updated_at
  - Для сценариев типа «стрижка на неделе» достаточно events без schedules/blocks

- user_achievements — выданные ачивки
  - Поля: id, user_id, achievement_code (уник. в сочетании с level), title, description, level, points, earned_at, metadata(JSONB)

Что исключено и почему:
- schedules/blocks — не храним версии расписаний и таймблоки отдельно; все события/напоминания ведутся в events
- resource_battery — на первом этапе не требуется
- attachments — не кэшируем медиа; история чата текстовая
- settings — компактные настройки держим в users.preferences

## 3.1. Синхронизация с ТЗ фронтенда (зафиксировано)

Ниже зафиксирован минимальный состав сущностей и полей, согласованный с фронтендом. Эти требования отражены в нашей схеме БД и используются в API/LLM tool‑use. Полная реализация полей и индексов — в [DATABASE_SCHEMA.md](TZGeneration-main/DATABASE_SCHEMA.md).

- users — профиль пользователя и базовые предпочтения
  - Поля (минимум): id (UUID, PK), email (unique), password_hash, full_name, timezone (IANA), locale, preferences(JSONB), created_at, updated_at, last_login_at
  - Примечание: отдельной таблицы settings нет; индивидуальные настройки храним в users.preferences

- chats — чат‑сессии на пользователя
  - Поля: id, user_id (FK→users), title, purpose(enum), last_message_at, is_archived, created_at, updated_at
  - Назначение: разделять контексты диалогов (не смешивать темы)

- chat_messages — сообщения в рамках чата (+журнал tool‑use)
  - Поля: id, chat_id (FK→chats), role(enum: user/assistant/tool/system), content_text, content_json(JSONB), tool_name (опц.), tool_args(JSONB, опц.), tool_result(JSONB, опц.), ai_provider/ai_model (опц.), token_usage_* (опц.), created_at
  - Назначение: хранение истории диалога и протоколирование вызовов инструментов

- events — унифицированные «событие/напоминание»
  - Поля: id, user_id (FK→users), title, description, start_at, end_at (NULL для напоминаний), all_day, type(enum: event/reminder), location, status(enum), source(enum: user/llm/import), created_via(enum: chat/ui/api), recurrence_rule (опц.), parent_event_id (опц.), tags(TEXT[]), created_at, updated_at
  - Примечание: для сценариев «стрижка на неделе» достаточно events без schedules/blocks

- user_achievements — выданные ачивки
  - Поля: id, user_id (FK→users), achievement_code (уникален в сочетании с level), title, description, level, points, earned_at, metadata(JSONB)

Статус: модель данных приведена в соответствие (включая индексы и ограничения) — см. [DATABASE_SCHEMA.md](TZGeneration-main/DATABASE_SCHEMA.md).

## 4. Группы API (черновой контур)
- Auth: POST /auth/register, POST /auth/login, GET /auth/me
- Chat:
  - POST /chats — создать чат
  - GET /chats — список чатов пользователя
  - GET /chats/{id}/messages — история
  - POST /chats/{id}/messages — отправка сообщения (проксирование в /api/llm/chat при необходимости)
- LLM proxy:
  - POST /api/llm/chat — оркестратор диалога: добавляет system-инструкции, описывает tools, вызывает провайдера, исполняет tool‑calls и возвращает финальный ответ
- Events:
  - GET /events?range=...&q=... — поиск по диапазону и тексту
  - POST /events — создать (из диалога или вручную)
  - PATCH /events/{id} — правки
  - DELETE /events/{id}
- Achievements:
  - GET /achievements — список
  - (добавление сервером по правилам геймификации)

## 5. LLM tool‑use: контракты инструментов
Инструменты описываются для модели как JSON‑схемы аргументов и сценарии вызовов.

- calendar.search_events(args)
  - user_timezone: string (IANA)
  - range: enum [today, tomorrow, this_week, next_week] | custom {start, end} (ISO‑8601)
  - query: string (опц.), напр. «стрижка»
  - include_types: array[event,reminder] (опц.)
  - limit: int (опц., default 20)
  - Ответ: items[] с {id, type, title, start_at, end_at, location, source}, summary
  - Когда вызывать: любой запрос «есть ли у меня/когда у меня ...» в привязке ко времени

- events.create(args) — включаем по готовности
  - title, start_at, end_at (опц.), type (event/reminder), location (опц.), source='llm', created_via='chat'
  - Ответ: созданное событие

Поведенческие правила в системном промпте:
- Chit‑chat («привет, как дела?»): не вызывать tools
- Запрос о личных данных с временной формулировкой: предпочитать calendar.search_events
- Недостаточно аргументов (нет диапазона/таймзоны): задать уточняющий вопрос
- Всегда учитывать users.timezone при нормализации «на неделе/завтра» и т.п.

## 6. Что писать в ТЗ (правки backend‑фокуса)
Править [TZGeneration-main/ТЗ/body.typ](TZGeneration-main/ТЗ/body.typ):
- Введение → «область применения»: backend обрабатывает текстовые запросы, при необходимости вызывает инструмент поиска событий
- Назначение разработки:
  - Функциональное: REST API + LLM‑интеграция (tool‑use), хранение чатов/событий, поиск
  - Эксплуатационное: сервис в контейнерах, клиент — iOS
- Требования к функциональным характеристикам:
  - Состав функций: auth, chat, events, achievements, LLM tool‑use (поиск событий, создание событий)
  - Входные/выходные данные: текстовые сообщения; JSON событий; ISO‑8601 время
  - Временные характеристики: поиск ≤ 200‑300 мс (БД), end‑to‑end чат с LLM синхронно ≤ 8 c
  - Интерфейс: OpenAPI 3.x, стабильные коды ответов, версионирование /api/v1
- Надежность:
  - Таймауты/ретраи для LLM, graceful degradation, идемпотентность по X‑Idempotency‑Key для создания событий
- Условия эксплуатации: типовое серверное ПО, DevOps‑обслуживание
- Состав и параметры ТС: Python 3.11+, FastAPI, PostgreSQL 14+, Docker, Uvicorn/Gunicorn
- Информационная и программная совместимость: JSON, ISO‑8601, JWT Bearer, HTTPS
- Исходные коды и языки: Python, типизация, black/ruff, mypy
- Защита информации: хеш паролей, секреты в env/secret store, аудит по логам (при необходимости)
- Технико‑экономические показатели: снижение временных затрат за счёт поиска и диалога
- Стадии и этапы: без schedules/blocks; фокус на chat/events и tool‑use
- Контроль и приемка: модульные/интеграционные тесты, контракт‑тесты инструментов

## 7. Пошаговый план внедрения
1) БД и модели (минимум)
- Создать таблицы: users, chats, chat_messages, events, user_achievements (см. [TZGeneration-main/DATABASE_SCHEMA.md](TZGeneration-main/DATABASE_SCHEMA.md))
- Индексы: по времени для events, по chat_id/created_at для сообщений, уникальность email

2) Каркас FastAPI
- Структура: /api/v1/auth, /api/v1/chats, /api/v1/events, /api/v1/achievements, /api/llm/chat
- Подключить OpenAPI, CORS, валидацию схем Pydantic

3) Auth/JWT
- Регистрация/логин, middleware извлечения пользователя, защищённые ручки

4) Chat + история
- CRUD чатов и сообщений
- Поддержка длинных контекстов: хранить только важные сообщения/резюме (по необходимости)

5) Events
- Поиск по диапазонам и тексту (ILIKE/FTS), создание/редактирование/удаление
- Нормализация «на неделе/завтра» → границы в user.timezone

6) LLM‑прокси и инструменты
- /api/llm/chat добавляет system‑prompt, описания tools
- Реализовать обработку tool‑call calendar.search_events
- Добавить few‑shot примеры для: chit‑chat, поиск событий, уточняющие вопросы

7) Тестирование
- Pytest: модульные (repo/сервисы), интеграционные (API), контракт‑тесты tool‑use
- Фикстуры для типовых событий (например, «стрижка»)

8) Документация и деплой
- README: env, миграции, локальный запуск, деплой
- Настроить Dockerfile/Compose, logging, базовые метрики

## 8. Критерии готовности backend
- Реализованы ручки auth, chats, events; /api/llm/chat оркестрирует tool‑use
- Поиск «у меня стрижка на неделе, когда?» возвращает корректные данные
- Все контракты документированы в OpenAPI, тесты зелёные
- Безопасность: JWT‑поток, секреты в env, пароли — в хеше

## 9. Риски и расширение в будущем
- Нет версий расписаний (schedules): не поддерживается откат/сравнение — если потребуется, добавим
- Нет resource_battery: можно ввести позднее без ломки схемы
- Нет attachments: кэш медиа можно добавить при переходе к Vision
- Возможное добавление tasks как черновиков (до превращения в events)

## 10. Что править прямо сейчас
- Обновить текст ТЗ в [TZGeneration-main/ТЗ/body.typ](TZGeneration-main/ТЗ/body.typ) согласно разделу 6
- Переписать схему в [TZGeneration-main/DATABASE_SCHEMA.md](TZGeneration-main/DATABASE_SCHEMA.md) под 5 таблиц (эта задача уже подготовлена концептуально)
- Согласовать описание инструментов tool‑use (раздел 5) и внести в ТЗ («Требования к функциональным характеристикам» как подпункт LLM‑интеграции)

Итог
- План и ТЗ приведены к минимальной жизнеспособной архитектуре (users, chats, chat_messages, events, user_achievements)
- LLM tool‑use описан, сценарии «когда у меня X?» покрыты calendar.search_events
- Дальнейшая работа: синхронизация контента body.typ и генерация PDF через Typst ([TZGeneration-main/ТЗ/main.typ](TZGeneration-main/ТЗ/main.typ))