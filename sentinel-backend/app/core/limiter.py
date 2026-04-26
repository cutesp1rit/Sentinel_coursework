from fastapi import Request
from slowapi import Limiter
from slowapi.util import get_remote_address


def _rate_limit_key(request: Request) -> str:
    # Use user_id from JWT sub claim when available, fall back to IP.
    # This prevents one user from consuming another user's quota on shared IPs.
    from app.core.config import settings
    from jose import jwt, JWTError

    auth_header = request.headers.get("Authorization", "")
    if auth_header.startswith("Bearer "):
        try:
            payload = jwt.decode(
                auth_header[7:],
                settings.SECRET_KEY,
                algorithms=[settings.ALGORITHM],
                options={"verify_exp": False},
            )
            sub = payload.get("sub")
            if sub:
                return f"user:{sub}"
        except JWTError:
            pass
    return get_remote_address(request)


limiter = Limiter(key_func=_rate_limit_key)
