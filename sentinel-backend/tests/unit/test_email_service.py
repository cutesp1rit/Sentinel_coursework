from unittest.mock import AsyncMock, patch, MagicMock

import pytest

from app.core.services import email_service


@pytest.mark.asyncio
class TestSendVerificationEmail:
    async def test_sends_message(self):
        mock_fastmail = MagicMock()
        mock_fastmail.send_message = AsyncMock()
        with patch("app.core.services.email_service.FastMail", return_value=mock_fastmail):
            await email_service.send_verification_email("user@example.com", "token123")
        mock_fastmail.send_message.assert_awaited_once()

    async def test_message_contains_token_url(self):
        captured = []

        async def capture(msg):
            captured.append(msg)

        mock_fastmail = MagicMock()
        mock_fastmail.send_message = capture
        with patch("app.core.services.email_service.FastMail", return_value=mock_fastmail):
            await email_service.send_verification_email("user@example.com", "tok_abc")

        assert captured
        assert "tok_abc" in captured[0].body

    async def test_recipient_is_correct(self):
        captured = []

        async def capture(msg):
            captured.append(msg)

        mock_fastmail = MagicMock()
        mock_fastmail.send_message = capture
        with patch("app.core.services.email_service.FastMail", return_value=mock_fastmail):
            await email_service.send_verification_email("target@example.com", "tok")

        assert any("target@example.com" in str(r) for r in captured[0].recipients)


@pytest.mark.asyncio
class TestSendPasswordResetEmail:
    async def test_sends_message(self):
        mock_fastmail = MagicMock()
        mock_fastmail.send_message = AsyncMock()
        with patch("app.core.services.email_service.FastMail", return_value=mock_fastmail):
            await email_service.send_password_reset_email("user@example.com", "resettoken")
        mock_fastmail.send_message.assert_awaited_once()

    async def test_message_contains_reset_token(self):
        captured = []

        async def capture(msg):
            captured.append(msg)

        mock_fastmail = MagicMock()
        mock_fastmail.send_message = capture
        with patch("app.core.services.email_service.FastMail", return_value=mock_fastmail):
            await email_service.send_password_reset_email("user@example.com", "reset_xyz")

        assert captured
        assert "reset_xyz" in captured[0].body

    async def test_recipient_is_correct(self):
        captured = []

        async def capture(msg):
            captured.append(msg)

        mock_fastmail = MagicMock()
        mock_fastmail.send_message = capture
        with patch("app.core.services.email_service.FastMail", return_value=mock_fastmail):
            await email_service.send_password_reset_email("reset@example.com", "tok")

        assert any("reset@example.com" in str(r) for r in captured[0].recipients)
