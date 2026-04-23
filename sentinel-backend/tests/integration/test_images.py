import pytest

# Minimal valid 1x1 PNG (used to avoid creating temp files)
MINIMAL_PNG = (
    b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01'
    b'\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00'
    b'\x00\x0cIDATx\x9cc\xf8\x0f\x00\x00\x11\x00\x01\x99\x00'
    b'\n\x00\x00\x00\x00IEND\xaeB`\x82'
)


@pytest.fixture(scope="module")
def chat(client, auth_headers):
    resp = client.post("/chats", json={"title": "Image test chat"}, headers=auth_headers)
    assert resp.status_code == 201, resp.text
    return resp.json()


class TestImageUpload:
    def test_upload_no_auth(self, client, chat):
        resp = client.post(
            f"/chats/{chat['id']}/upload",
            files={"file": ("photo.png", MINIMAL_PNG, "image/png")},
        )
        assert resp.status_code == 401

    def test_upload_nonexistent_chat(self, client, auth_headers):
        fake_id = "00000000-0000-0000-0000-000000000000"
        resp = client.post(
            f"/chats/{fake_id}/upload",
            files={"file": ("photo.png", MINIMAL_PNG, "image/png")},
            headers=auth_headers,
        )
        assert resp.status_code == 404

    def test_upload_disallowed_file_type(self, client, auth_headers, chat):
        resp = client.post(
            f"/chats/{chat['id']}/upload",
            files={"file": ("document.pdf", b"%PDF-1.4 fake", "application/pdf")},
            headers=auth_headers,
        )
        assert resp.status_code == 400
        assert "not allowed" in resp.json()["detail"].lower()

    def test_upload_gif_disallowed(self, client, auth_headers, chat):
        resp = client.post(
            f"/chats/{chat['id']}/upload",
            files={"file": ("anim.gif", b"GIF89a", "image/gif")},
            headers=auth_headers,
        )
        assert resp.status_code == 400

    def test_upload_valid_image_returns_url(self, client, auth_headers, chat):
        resp = client.post(
            f"/chats/{chat['id']}/upload",
            files={"file": ("photo.png", MINIMAL_PNG, "image/png")},
            headers=auth_headers,
        )
        if resp.status_code == 503:
            pytest.skip("Storage service unavailable (503) — check S3 settings")
        assert resp.status_code == 201, resp.text
        body = resp.json()
        assert "url" in body
        assert body["url"].startswith("http")
        assert body["filename"] == "photo.png"
        assert body["mime_type"] == "image/png"


class TestImageMessage:
    def test_send_message_with_images_stores_structured_content(self, client, auth_headers, chat):
        """User message with images should be stored with image_message structured content."""
        resp = client.post(
            f"/chats/{chat['id']}/messages",
            json={
                "role": "user",
                "content_text": "What's in this photo?",
                "images": [
                    {
                        "url": "https://example.com/photo.jpg",
                        "filename": "photo.jpg",
                        "mime_type": "image/jpeg",
                    }
                ],
            },
            headers=auth_headers,
            timeout=60,
        )
        if resp.status_code == 503:
            pytest.skip("LLM service unavailable (503)")
        assert resp.status_code == 201, resp.text
        # Response is the assistant's reply, not the user message
        body = resp.json()
        assert body["role"] == "assistant"

    def test_message_history_contains_image_message_type(self, client, auth_headers, chat):
        """After sending an image message, history must include it with image_message structured content."""
        resp = client.get(f"/chats/{chat['id']}/messages", headers=auth_headers)
        assert resp.status_code == 200
        items = resp.json()["items"]

        image_user_messages = [
            m for m in items
            if m["role"] == "user"
            and m.get("content_structured") is not None
            and m["content_structured"].get("type") == "image_message"
        ]
        # This test only makes sense if the previous test ran and wasn't skipped
        if not image_user_messages:
            pytest.skip("No image messages in history (previous test may have been skipped)")

        msg = image_user_messages[-1]
        assert msg["content_text"] == "What's in this photo?"
        images = msg["content_structured"]["images"]
        assert len(images) >= 1
        assert images[0]["url"] == "https://example.com/photo.jpg"
        assert images[0]["filename"] == "photo.jpg"

    def test_send_text_only_message_has_no_image_structured_content(self, client, auth_headers, chat):
        """Plain text messages must not produce image_message structured content."""
        resp = client.post(
            f"/chats/{chat['id']}/messages",
            json={"role": "user", "content_text": "Привет!"},
            headers=auth_headers,
            timeout=60,
        )
        if resp.status_code == 503:
            pytest.skip("LLM service unavailable (503)")
        assert resp.status_code == 201, resp.text

        history_resp = client.get(f"/chats/{chat['id']}/messages", headers=auth_headers)
        items = history_resp.json()["items"]

        last_user_msg = next(
            (m for m in reversed(items) if m["role"] == "user"),
            None,
        )
        assert last_user_msg is not None
        structured = last_user_msg.get("content_structured")
        assert structured is None or structured.get("type") != "image_message"

    def test_send_image_message_no_auth(self, client, chat):
        resp = client.post(
            f"/chats/{chat['id']}/messages",
            json={
                "role": "user",
                "content_text": "photo",
                "images": [{"url": "https://example.com/x.jpg", "filename": "x.jpg", "mime_type": "image/jpeg"}],
            },
        )
        assert resp.status_code == 401
