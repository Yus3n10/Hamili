import time
from collections import defaultdict, deque

from fastapi import HTTPException
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address, default_limits=["200/minute"])

REGISTER_LIMIT = "30 per hour"
AI_LIMIT = "20 per minute"

_LOGIN_MAX_FAILURES = 5
_LOGIN_WINDOW_SECONDS = 900
_login_failures: dict[str, deque] = defaultdict(deque)


def _prune(dq: deque, now: float) -> None:
    while dq and now - dq[0] > _LOGIN_WINDOW_SECONDS:
        dq.popleft()


def ensure_login_allowed(ip: str) -> None:
    if not limiter.enabled:
        return
    dq = _login_failures[ip]
    _prune(dq, time.time())
    if len(dq) >= _LOGIN_MAX_FAILURES:
        raise HTTPException(
            status_code=429,
            detail="Too many failed login attempts. Please try again in a few minutes.",
        )


def record_login_failure(ip: str) -> None:
    _login_failures[ip].append(time.time())


def reset_login_failures(ip: str) -> None:
    _login_failures.pop(ip, None)
