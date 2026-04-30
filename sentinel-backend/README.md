# Sentinel Backend

REST API for the Sentinel iOS app. FastAPI + PostgreSQL + SQLAlchemy 2.0.

## Running

```bash
cp .env.example .env
docker-compose up --build
```

API: http://localhost:8000  
Docs: http://localhost:8000/docs

## Environment variables

| Variable | Description |
|---|---|
| `DATABASE_URL` | `postgresql+asyncpg://user:pass@host:5432/db` |
| `DATABASE_SYNC_URL` | `postgresql://user:pass@host:5432/db` |
| `SECRET_KEY` | Secret key for signing JWTs |
| `LLM_API_KEY` | LLM provider API key |
| `LLM_MODEL` | Model identifier |
| `LLM_BASE_URL` | Base URL of the OpenAI-compatible API |
| `BACKEND_CORS_ORIGINS` | Allowed origins, comma-separated |

## Tests

```bash
pytest tests/unit/ -v
pytest tests/integration/ -v
```

## Migrations

```bash
alembic upgrade head
alembic revision --autogenerate -m "description"
alembic downgrade -1
```
