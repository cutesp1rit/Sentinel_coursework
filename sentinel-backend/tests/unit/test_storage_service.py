import uuid
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.core.services import storage_service


def _make_s3_client_mock():
    """Async context manager mock for aioboto3 S3 client."""
    mock_client = AsyncMock()
    mock_client.put_object = AsyncMock()

    cm = MagicMock()
    cm.__aenter__ = AsyncMock(return_value=mock_client)
    cm.__aexit__ = AsyncMock(return_value=False)

    session_mock = MagicMock()
    session_mock.client.return_value = cm
    return session_mock, mock_client


class TestUploadImageUrl:
    @pytest.mark.asyncio
    async def test_returned_url_uses_public_url_and_bucket_path(self):
        session_mock, _ = _make_s3_client_mock()
        chat_id = uuid.UUID("11111111-1111-1111-1111-111111111111")

        with patch.object(storage_service, "_session", session_mock), \
             patch.object(storage_service.settings, "S3_PUBLIC_URL", "https://pub.example.com"), \
             patch.object(storage_service.settings, "S3_BUCKET_NAME", "test-bucket"), \
             patch.object(storage_service.settings, "S3_ACCESS_KEY", "key"), \
             patch.object(storage_service.settings, "S3_SECRET_KEY", "secret"), \
             patch.object(storage_service.settings, "S3_REGION", "auto"), \
             patch.object(storage_service.settings, "S3_ENDPOINT_URL", "https://s3.example.com"):

            url = await storage_service.upload_image(b"data", "photo.png", "image/png", chat_id)

        assert url.startswith("https://pub.example.com/")
        assert f"chats/{chat_id}/" in url
        assert url.endswith(".png")

    @pytest.mark.asyncio
    async def test_object_key_passed_to_put_object(self):
        session_mock, s3_mock = _make_s3_client_mock()
        chat_id = uuid.UUID("22222222-2222-2222-2222-222222222222")

        with patch.object(storage_service, "_session", session_mock), \
             patch.object(storage_service.settings, "S3_PUBLIC_URL", "https://pub.example.com"), \
             patch.object(storage_service.settings, "S3_BUCKET_NAME", "my-bucket"), \
             patch.object(storage_service.settings, "S3_ACCESS_KEY", "k"), \
             patch.object(storage_service.settings, "S3_SECRET_KEY", "s"), \
             patch.object(storage_service.settings, "S3_REGION", "auto"), \
             patch.object(storage_service.settings, "S3_ENDPOINT_URL", "https://s3.example.com"):

            await storage_service.upload_image(b"bytes", "image.jpg", "image/jpeg", chat_id)

        s3_mock.put_object.assert_awaited_once()
        call_kwargs = s3_mock.put_object.call_args.kwargs
        assert call_kwargs["Bucket"] == "my-bucket"
        assert call_kwargs["Key"].startswith(f"chats/{chat_id}/")
        assert call_kwargs["Key"].endswith(".jpg")
        assert call_kwargs["Body"] == b"bytes"
        assert call_kwargs["ContentType"] == "image/jpeg"


class TestContentTypeResolution:
    @pytest.mark.asyncio
    async def test_explicit_content_type_is_used(self):
        session_mock, s3_mock = _make_s3_client_mock()
        chat_id = uuid.uuid4()

        with patch.object(storage_service, "_session", session_mock), \
             patch.object(storage_service.settings, "S3_PUBLIC_URL", "https://p.example.com"), \
             patch.object(storage_service.settings, "S3_BUCKET_NAME", "b"), \
             patch.object(storage_service.settings, "S3_ACCESS_KEY", "k"), \
             patch.object(storage_service.settings, "S3_SECRET_KEY", "s"), \
             patch.object(storage_service.settings, "S3_REGION", "auto"), \
             patch.object(storage_service.settings, "S3_ENDPOINT_URL", "https://s3.example.com"):

            await storage_service.upload_image(b"data", "img.png", "image/png", chat_id)

        call_kwargs = s3_mock.put_object.call_args.kwargs
        assert call_kwargs["ContentType"] == "image/png"

    @pytest.mark.asyncio
    async def test_none_content_type_resolved_from_extension(self):
        session_mock, s3_mock = _make_s3_client_mock()
        chat_id = uuid.uuid4()

        with patch.object(storage_service, "_session", session_mock), \
             patch.object(storage_service.settings, "S3_PUBLIC_URL", "https://p.example.com"), \
             patch.object(storage_service.settings, "S3_BUCKET_NAME", "b"), \
             patch.object(storage_service.settings, "S3_ACCESS_KEY", "k"), \
             patch.object(storage_service.settings, "S3_SECRET_KEY", "s"), \
             patch.object(storage_service.settings, "S3_REGION", "auto"), \
             patch.object(storage_service.settings, "S3_ENDPOINT_URL", "https://s3.example.com"):

            await storage_service.upload_image(b"data", "photo.jpeg", None, chat_id)

        call_kwargs = s3_mock.put_object.call_args.kwargs
        assert call_kwargs["ContentType"] == "image/jpeg"

    @pytest.mark.asyncio
    async def test_unknown_extension_falls_back_to_octet_stream(self):
        session_mock, s3_mock = _make_s3_client_mock()
        chat_id = uuid.uuid4()

        with patch.object(storage_service, "_session", session_mock), \
             patch.object(storage_service.settings, "S3_PUBLIC_URL", "https://p.example.com"), \
             patch.object(storage_service.settings, "S3_BUCKET_NAME", "b"), \
             patch.object(storage_service.settings, "S3_ACCESS_KEY", "k"), \
             patch.object(storage_service.settings, "S3_SECRET_KEY", "s"), \
             patch.object(storage_service.settings, "S3_REGION", "auto"), \
             patch.object(storage_service.settings, "S3_ENDPOINT_URL", "https://s3.example.com"):

            await storage_service.upload_image(b"data", "file.xyz", None, chat_id)

        call_kwargs = s3_mock.put_object.call_args.kwargs
        assert call_kwargs["ContentType"] == "application/octet-stream"
