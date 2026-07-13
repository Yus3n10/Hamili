import json

import google.generativeai as genai

from app.core.config import get_settings
from app.services.ai.base_provider import AIProvider, AIProviderUnavailable, looks_like_quota_error
from app.services.ai.prompt_templates import (
    HAMI_AGENT_SYSTEM,
    HAMI_SYSTEM_PROMPT,
    build_agent_prompt,
    build_insight_prompt,
)

settings = get_settings()


class GeminiProvider(AIProvider):
    """Google Gemini implementation. Uses the free-tier `gemini-1.5-flash`
    model by default — fast and cheap enough for chat + insight generation."""

    def __init__(self, model_name: str = "gemini-flash-lite-latest"):
        genai.configure(api_key=settings.gemini_api_key)
        self._model_name = model_name
        self.model = genai.GenerativeModel(
            model_name=model_name,
            system_instruction=HAMI_SYSTEM_PROMPT,
            generation_config=genai.GenerationConfig(max_output_tokens=200),
        )

    def chat(self, messages: list[dict], financial_context: dict) -> str:
        history = [
            {"role": "user" if m["role"] == "user" else "model", "parts": [m["content"]]}
            for m in messages[:-1]
        ]
        chat_session = self.model.start_chat(history=history)

        latest_user_message = messages[-1]["content"]
        prompt = f"Financial snapshot:\n{json.dumps(financial_context)}\n\nUser: {latest_user_message}"

        try:
            response = chat_session.send_message(prompt)
        except Exception as err:  # noqa: BLE001 — classify then re-raise
            if looks_like_quota_error(err):
                raise AIProviderUnavailable from err
            raise
        return response.text.strip()

    def interpret(
        self,
        messages: list[dict],
        financial_context: dict,
        category_names: list[str],
        today: str,
    ) -> dict:
        conversation = "\n".join(f"{m['role']}: {m['content']}" for m in messages[-6:])
        prompt = build_agent_prompt(json.dumps(financial_context), category_names, today, conversation)
        model = genai.GenerativeModel(
            model_name=self._model_name,
            system_instruction=HAMI_AGENT_SYSTEM,
            generation_config=genai.GenerationConfig(
                response_mime_type="application/json",
                max_output_tokens=500,
            ),
        )
        try:
            response = model.generate_content(prompt)
        except Exception as err:  # noqa: BLE001 — classify then re-raise
            if looks_like_quota_error(err):
                raise AIProviderUnavailable from err
            raise

        try:
            cleaned = response.text.strip().removeprefix("```json").removesuffix("```").strip()
            data = json.loads(cleaned)
            if not isinstance(data, dict):
                raise ValueError("not an object")
            data.setdefault("action", "none")
            data.setdefault("params", {})
            data.setdefault("reply", "")
            return data
        except (json.JSONDecodeError, AttributeError, ValueError):
            text = (getattr(response, "text", "") or "").strip()
            return {"action": "none", "params": {}, "reply": text or "Sorry, I didn't catch that."}

    def generate_insights(self, financial_context: dict) -> list[str]:
        prompt = build_insight_prompt(json.dumps(financial_context))
        response = self.model.generate_content(prompt)

        try:
            cleaned = response.text.strip().removeprefix("```json").removesuffix("```").strip()
            return json.loads(cleaned)
        except (json.JSONDecodeError, AttributeError):
            return []
