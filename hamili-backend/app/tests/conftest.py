"""Test setup: disable rate limiting so the suite (which registers many users
from one client) isn't throttled. Rate limiting is verified separately against
a live server."""
from app.core.rate_limit import limiter

limiter.enabled = False
