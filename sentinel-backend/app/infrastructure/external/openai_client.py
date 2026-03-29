from openai import AsyncOpenAI

from app.core.config import settings


def get_llm_client() -> AsyncOpenAI:
    return AsyncOpenAI(
        api_key=settings.LLM_API_KEY,
        base_url=settings.LLM_BASE_URL or None,
    )
