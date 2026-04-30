import os
import subprocess
import uuid

import pytest
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from starlette.testclient import TestClient

_TEST_DB_ASYNC = "postgresql+asyncpg://sentinel_user:sentinel_password@localhost:5432/sentinel_test"
_TEST_DB_SYNC = "postgresql://sentinel_user:sentinel_password@localhost:5432/sentinel_test"

# Patch S3 to use localhost (Docker exposes port 9000 to host)
# Must happen before app imports so storage_service picks it up at call time.
os.environ.setdefault("S3_ENDPOINT_URL", "http://localhost:9000")
os.environ.setdefault("S3_PUBLIC_URL", "http://localhost:9000/sentinel-media")

from app.main import app  # noqa: E402
from app.infrastructure.database.base import get_db  # noqa: E402

_engine = create_async_engine(_TEST_DB_ASYNC, echo=False, pool_pre_ping=True)
_SessionLocal = async_sessionmaker(_engine, class_=AsyncSession, expire_on_commit=False)


async def _get_test_db():
    async with _SessionLocal() as session:
        yield session


def _run_migrations() -> None:
    sentinel_backend = os.path.join(os.path.dirname(__file__), "..", "..")
    result = subprocess.run(
        ["venv/bin/alembic", "upgrade", "head"],
        env={**os.environ, "DATABASE_SYNC_URL": _TEST_DB_SYNC},
        capture_output=True,
        text=True,
        cwd=os.path.realpath(sentinel_backend),
    )
    if result.returncode != 0:
        raise RuntimeError(f"Alembic migration failed:\n{result.stderr}")


def pytest_sessionstart(session: pytest.Session) -> None:
    _run_migrations()


@pytest.fixture(scope="session")
def client():
    app.dependency_overrides[get_db] = _get_test_db
    with TestClient(app, base_url="http://test/api/v1", raise_server_exceptions=True) as c:
        yield c
    app.dependency_overrides.clear()


def unique_email() -> str:
    return f"test_{uuid.uuid4().hex[:8]}@example.com"


@pytest.fixture(scope="session")
def registered_user(client):
    email = unique_email()
    password = "StrongPass1!"
    resp = client.post("/auth/register", json={"email": email, "password": password})
    assert resp.status_code == 201, resp.text
    return {"email": email, "password": password, "user": resp.json()}


@pytest.fixture(scope="session")
def auth_headers(client, registered_user):
    resp = client.post(
        "/auth/login",
        json={
            "email": registered_user["email"],
            "password": registered_user["password"],
        },
    )
    assert resp.status_code == 200, resp.text
    token = resp.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}
