"""
AI provider interface.

Every LLM backend (Gemini today, OpenAI/Claude/local model tomorrow) must
implement this interface. Nothing outside this `ai/` package should ever
import a provider-specific SDK directly — routers and services depend only
on `AIProvider`, so swapping providers means writing one new class and
changing one line in `get_ai_provider()`.
"""

from abc import ABC, abstractmethod


class AIProviderUnavailable(Exception):
    """Raised when the AI backend can't serve a request because its quota
    is exhausted (or it is otherwise temporarily unavailable). Callers turn
    this into a friendly, user-facing 'try again later' message rather than
    a hard error."""


def looks_like_quota_error(err: Exception) -> bool:
    """Heuristic: does this exception look like a rate-limit / quota / 429?
    Kept broad because the Gemini SDK surfaces quota errors under several
    exception types and messages."""
    text = f"{type(err).__name__} {err}".lower()
    return any(
        marker in text
        for marker in ("resourceexhausted", "quota", "429", "exhausted", "rate limit", "ratelimit")
    )


class AIProvider(ABC):
    @abstractmethod
    def chat(self, messages: list[dict], financial_context: dict) -> str:
        """Generate a conversational reply given chat history and the
        user's current financial snapshot."""
        raise NotImplementedError

    @abstractmethod
    def generate_insights(self, financial_context: dict) -> list[str]:
        """Generate proactive insight strings (overspending alerts,
        goal-progress nudges, subscription suggestions) from a snapshot."""
        raise NotImplementedError

    @abstractmethod
    def interpret(
        self,
        messages: list[dict],
        financial_context: dict,
        category_names: list[str],
        today: str,
    ) -> dict:
        """Interpret the conversation as either a normal reply or an action
        request. Returns a dict: {"action": str, "params": dict, "reply": str}."""
        raise NotImplementedError
