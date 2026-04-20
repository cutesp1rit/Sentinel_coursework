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
        <h2>Подтвердите вашу почту</h2>
        <p>Для завершения регистрации в Sentinel нажмите кнопку ниже:</p>
        <p>
            <a href="{verify_url}"
               style="display:inline-block;padding:12px 24px;background:#000;color:#fff;
                      text-decoration:none;border-radius:6px;">
                Подтвердить почту
            </a>
        </p>
        <p style="color:#666;font-size:13px;">
            Ссылка действительна 24 часа.<br>
            Если вы не регистрировались в Sentinel — просто проигнорируйте это письмо.
        </p>
    </div>
    """
    message = MessageSchema(
        subject="Подтвердите вашу почту — Sentinel",
        recipients=[email],
        body=html,
        subtype=MessageType.html,
    )
    await FastMail(_get_mail_config()).send_message(message)


async def send_password_reset_email(email: str, token: str) -> None:
    reset_url = f"{settings.FRONTEND_URL}?reset_token={token}"
    html = f"""
    <div style="font-family: sans-serif; max-width: 480px; margin: 0 auto;">
        <h2>Сброс пароля</h2>
        <p>Вы запросили сброс пароля для вашего аккаунта Sentinel.</p>
        <p>
            <a href="{reset_url}"
               style="display:inline-block;padding:12px 24px;background:#000;color:#fff;
                      text-decoration:none;border-radius:6px;">
                Сбросить пароль
            </a>
        </p>
        <p style="color:#666;font-size:13px;">
            Ссылка действительна 1 час.<br>
            Если вы не запрашивали сброс пароля — просто проигнорируйте это письмо.
        </p>
    </div>
    """
    message = MessageSchema(
        subject="Сброс пароля — Sentinel",
        recipients=[email],
        body=html,
        subtype=MessageType.html,
    )
    await FastMail(_get_mail_config()).send_message(message)
