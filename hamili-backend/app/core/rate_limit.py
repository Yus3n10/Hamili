"""Shared rate limiter.

A single Limiter instance is created here so routers can apply per-route limits
(e.g. login) while `main` installs the global default and error handler. Keyed
by client IP; behind a proxy (Render), the platform sets X-Forwarded-For which
get_remote_address honours when the app is run with proxy headers enabled.
"""
from slowapi import Limiter
from slowapi.util import get_remote_address

# Global fallback applied to every route; specific routes tighten this.
limiter = Limiter(key_func=get_remote_address, default_limits=["200/minute"])

# Login/registration: throttle credential-stuffing / brute force.
LOGIN_LIMIT = "5 per 15 minutes"
# Chat/insights hit the paid AI provider — keep them modest.
AI_LIMIT = "20 per minute"
