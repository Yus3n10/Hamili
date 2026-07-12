"""
AI provider interface.

Every LLM backend (Gemini today, OpenAI/Claude/local model tomorrow) must
implement this interface. Nothing outside this `ai/` package should ever
import a provider-specific SDK directly — routers and services depend only
on `AIProvider`, so swapping providers means writing one new class and
changing one line in `get_ai_provider()`.
"""

from abc import ABC, abstractmethod


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
