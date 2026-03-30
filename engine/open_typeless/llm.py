"""Provider-agnostic LLM integration (OpenAI Chat Completions-compatible API)."""

import httpx

from .config import get_config
from .models import PromptMessages


class LLMError(Exception):
    pass


async def polish(prompt: PromptMessages, model: str | None = None) -> str:
    """Send assembled prompt to the configured LLM API and return polished text.

    Calls {llm.api_base}/chat/completions.
    """
    config = get_config()
    if config is None:
        raise LLMError("LLM is not configured. Call POST /config first.")

    llm = config.llm
    url = f"{llm.api_base.rstrip('/')}/chat/completions"
    model_to_use = model or llm.model

    payload = {
        "model": model_to_use,
        "messages": [
            {"role": "system", "content": prompt.system},
            {"role": "user", "content": prompt.user},
        ],
    }

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(
                url,
                headers={
                    "Authorization": f"Bearer {llm.api_key}",
                    "Content-Type": "application/json",
                },
                json=payload,
            )
    except httpx.TimeoutException:
        raise LLMError(f"LLM API request to {llm.api_base} timed out after 30 seconds")
    except httpx.RequestError as e:
        raise LLMError(f"LLM API request failed: {e}")

    if resp.status_code != 200:
        raise LLMError(
            f"LLM API returned {resp.status_code}: {resp.text}"
        )

    result = resp.json()
    try:
        return result["choices"][0]["message"]["content"].strip()
    except (KeyError, IndexError):
        raise LLMError(f"Unexpected LLM response format: {result}")
