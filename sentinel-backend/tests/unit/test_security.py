import uuid
from datetime import timedelta

import pytest

from app.core.security import (
    create_access_token,
    decode_access_token,
    get_password_hash,
    verify_password,
)


class TestPasswordHashing:
    def test_correct_password_verifies(self):
        hashed = get_password_hash("mySecret123!")
        assert verify_password("mySecret123!", hashed) is True

    def test_wrong_password_rejected(self):
        hashed = get_password_hash("mySecret123!")
        assert verify_password("wrongPassword", hashed) is False

    def test_empty_password_rejected(self):
        hashed = get_password_hash("mySecret123!")
        assert verify_password("", hashed) is False

    def test_similar_password_rejected(self):
        # "mySecret123!" vs "mySecret123" — trailing char matters
        hashed = get_password_hash("mySecret123!")
        assert verify_password("mySecret123", hashed) is False

    def test_hash_is_not_plaintext(self):
        password = "mySecret123!"
        hashed = get_password_hash(password)
        assert hashed != password


class TestDecodeAccessToken:
    def test_valid_token_returns_uuid(self):
        user_id = uuid.uuid4()
        token = create_access_token({"sub": str(user_id)})
        result = decode_access_token(token)
        assert result == user_id

    def test_expired_token_returns_none(self):
        user_id = uuid.uuid4()
        token = create_access_token({"sub": str(user_id)}, expires_delta=timedelta(seconds=-1))
        assert decode_access_token(token) is None

    def test_token_without_sub_returns_none(self):
        token = create_access_token({"role": "admin"})
        assert decode_access_token(token) is None

    def test_tampered_token_returns_none(self):
        user_id = uuid.uuid4()
        token = create_access_token({"sub": str(user_id)})
        tampered = token[:-10] + "AAAAAAAAAA"
        assert decode_access_token(tampered) is None

    def test_garbage_string_returns_none(self):
        assert decode_access_token("not.a.jwt.token") is None

    def test_empty_string_returns_none(self):
        assert decode_access_token("") is None

    def test_sub_is_not_uuid_returns_none(self):
        # sub="admin" instead of a UUID must be rejected
        token = create_access_token({"sub": "admin"})
        assert decode_access_token(token) is None
