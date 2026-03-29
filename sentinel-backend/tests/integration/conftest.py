import uuid
import pytest
import httpx

BASE_URL = "http://localhost:8000/api/v1"


def unique_email() -> str:
    return f"test_{uuid.uuid4().hex[:8]}@example.com"


@pytest.fixture(scope="session")
def client():
    with httpx.Client(base_url=BASE_URL, timeout=30, follow_redirects=True) as c:
        yield c


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
