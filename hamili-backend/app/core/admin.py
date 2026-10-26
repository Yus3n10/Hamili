from fastapi import Depends, HTTPException, Request, Response, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.security import decode_token
from app.db.session import get_db
from app.models.activity import AdminAccessLog
from app.models.user import User

_optional_bearer = HTTPBearer(auto_error=False)


def require_admin(
    request: Request,
    response: Response,
    credentials: HTTPAuthorizationCredentials | None = Depends(_optional_bearer),
    db: Session = Depends(get_db),
) -> User:
    """Admin routes answer 404 to everyone else, including requests with no
    or a bad token, so they look exactly like routes that don't exist."""
    not_found = HTTPException(status.HTTP_404_NOT_FOUND, "Not Found")
    payload = decode_token(credentials.credentials) if credentials else None
    if not payload or payload.get("type") != "access":
        raise not_found
    user_id = int(payload["sub"])
    if user_id not in get_settings().admin_id_set:
        raise not_found
    user = db.get(User, user_id)
    if user is None:
        raise not_found

    db.add(AdminAccessLog(admin_user_id=user.id, path=request.url.path[:200]))
    db.commit()
    response.headers["Cache-Control"] = "no-store"
    return user
