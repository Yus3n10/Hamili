"""
Provider factory. This is the ONE place that decides which AIProvider
implementation is active, based on the AI_PROVIDER env var. Adding a new
provider later means: write a class implementing AIProvider, add one
elif branch here.
"""

from functools import lru_cache

from app.core.config import get_settings
from app.services.ai.base_provider import AIProvider


@lru_cache
def get_ai_provider() -> AIProvider:
    settings = get_settings()

    if settings.ai_provider == "gemini":
        from app.services.ai.gemini_provider import GeminiProvider

        return GeminiProvider()

    raise ValueError(f"Unsupported AI_PROVIDER: {settings.ai_provider}")
