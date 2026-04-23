import uuid

import aioboto3

from app.core.config import settings

_MIME_BY_EXT = {
    "jpg": "image/jpeg",
    "jpeg": "image/jpeg",
    "png": "image/png",
    "gif": "image/gif",
    "webp": "image/webp",
    "heic": "image/heic",
}

_session = aioboto3.Session()


async def upload_image(
    file_bytes: bytes,
    filename: str,
    content_type: str | None,
    chat_id: uuid.UUID,
) -> str:
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else "bin"
    resolved_content_type = content_type or _MIME_BY_EXT.get(ext, "application/octet-stream")
    object_key = f"chats/{chat_id}/{uuid.uuid4()}.{ext}"

    async with _session.client(
        "s3",
        endpoint_url=settings.S3_ENDPOINT_URL,
        aws_access_key_id=settings.S3_ACCESS_KEY,
        aws_secret_access_key=settings.S3_SECRET_KEY,
        region_name=settings.S3_REGION,
    ) as client:
        await client.put_object(
            Bucket=settings.S3_BUCKET_NAME,
            Key=object_key,
            Body=file_bytes,
            ContentType=resolved_content_type,
        )

    return f"{settings.S3_PUBLIC_URL.rstrip('/')}/{object_key}"
