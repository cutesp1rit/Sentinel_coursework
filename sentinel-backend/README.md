# Sentinel Backend

REST API для iOS-приложения Sentinel. FastAPI + PostgreSQL + SQLAlchemy 2.0.

## Запуск

```bash
cp .env.example .env
docker-compose up --build
```

API: http://localhost:8000  
Docs: http://localhost:8000/docs

## Переменные окружения

| Переменная | Описание |
|---|---|
| `DATABASE_URL` | `postgresql+asyncpg://user:pass@host:5432/db` |
| `DATABASE_SYNC_URL` | `postgresql://user:pass@host:5432/db` |
| `SECRET_KEY` | Секрет для подписи JWT |
| `LLM_API_KEY` | API-ключ провайдера LLM |
| `LLM_MODEL` | Идентификатор модели |
| `LLM_BASE_URL` | Base URL OpenAI-совместимого API |
| `BACKEND_CORS_ORIGINS` | Разрешённые origin через запятую |

## Тесты

```bash
pytest tests/unit/ -v
pytest tests/integration/ -v
```

## Миграции

```bash
alembic upgrade head
alembic revision --autogenerate -m "description"
alembic downgrade -1
```
