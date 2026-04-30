from fastapi_mail import FastMail, MessageSchema, ConnectionConfig, MessageType

from app.core.config import settings


def _get_mail_config() -> ConnectionConfig:
    return ConnectionConfig(
        MAIL_USERNAME=settings.SMTP_USER,
        MAIL_PASSWORD=settings.SMTP_PASSWORD,
        MAIL_FROM=settings.EMAILS_FROM,
        MAIL_FROM_NAME=settings.EMAILS_FROM_NAME,
        MAIL_PORT=settings.SMTP_PORT,
        MAIL_SERVER=settings.SMTP_HOST,
        MAIL_STARTTLS=True,
        MAIL_SSL_TLS=False,
        USE_CREDENTIALS=True,
        VALIDATE_CERTS=True,
    )


async def send_verification_email(email: str, token: str) -> None:
    verify_url = f"{settings.FRONTEND_URL}?verify_token={token}"
    html = f"""
    <div style="font-family: sans-serif; max-width: 480px; margin: 0 auto;">
        <h2>Confirm your email</h2>
        <p>Click the button below to complete your Sentinel registration:</p>
        <p>
            <a href="{verify_url}"
               style="display:inline-block;padding:12px 24px;background:#000;color:#fff;
                      text-decoration:none;border-radius:6px;">
                Confirm email
            </a>
        </p>
        <p style="color:#666;font-size:13px;">
            This link is valid for 24 hours.<br>
            If you did not register with Sentinel, you can safely ignore this email.
        </p>
    </div>
    """
    message = MessageSchema(
        subject="Confirm your email — Sentinel",
        recipients=[email],
        body=html,
        subtype=MessageType.html,
    )
    await FastMail(_get_mail_config()).send_message(message)


async def send_password_reset_email(email: str, token: str) -> None:
    reset_url = f"{settings.FRONTEND_URL}?reset_token={token}"
    html = f"""
    <div style="font-family: sans-serif; max-width: 480px; margin: 0 auto;">
        <h2>Reset your password</h2>
        <p>You requested a password reset for your Sentinel account.</p>
        <p>
            <a href="{reset_url}"
               style="display:inline-block;padding:12px 24px;background:#000;color:#fff;
                      text-decoration:none;border-radius:6px;">
                Reset password
            </a>
        </p>
        <p style="color:#666;font-size:13px;">
            This link is valid for 1 hour.<br>
            If you did not request a password reset, you can safely ignore this email.
        </p>
    </div>
    """
    message = MessageSchema(
        subject="Reset your password — Sentinel",
        recipients=[email],
        body=html,
        subtype=MessageType.html,
    )
    await FastMail(_get_mail_config()).send_message(message)
