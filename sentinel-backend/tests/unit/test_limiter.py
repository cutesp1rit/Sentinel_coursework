import uuid

import pytest
from jose import jwt
from starlette.datastructures import Headers
from starlette.testclient import TestClient
from starlette.types import Scope

from app.core.config import settings
from app.core.limiter import _rate_limit_key


def _make_request(auth_header: str | None = None, client_ip: str = "1.2.3.4"):
    headers = {}
    if auth_header is not None:
        headers["authorization"] = auth_header

    scope: Scope = {
        "type": "http",
        "method": "POST",
        "path": "/",
        "headers": Headers(headers=headers).raw,
        "client": (client_ip, 12345),
        "query_string": b"",
        "root_path": "",
    }

    from starlette.requests import Request
    return Request(scope)


def _make_token(sub: str) -> str:
    return jwt.encode({"sub": sub}, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


class TestRateLimitKey:
    def test_valid_jwt_returns_user_key(self):
        user_id = str(uuid.uuid4())
        token = _make_token(user_id)
        request = _make_request(auth_header=f"Bearer {token}")

        key = _rate_limit_key(request)

        assert key == f"user:{user_id}"

    def test_invalid_jwt_falls_back_to_ip(self):
        request = _make_request(auth_header="Bearer not.a.real.token", client_ip="5.6.7.8")

        key = _rate_limit_key(request)

        assert key == "5.6.7.8"

    def test_no_auth_header_falls_back_to_ip(self):
        request = _make_request(client_ip="9.10.11.12")

        key = _rate_limit_key(request)

        assert key == "9.10.11.12"

    def test_bearer_prefix_without_token_falls_back_to_ip(self):
        request = _make_request(auth_header="Bearer ", client_ip="1.1.1.1")

        key = _rate_limit_key(request)

        assert key == "1.1.1.1"
