"""Tests for LLM integration with mocked API responses."""

import httpx
import pytest

from open_typeless.config import set_config
from open_typeless.llm import LLMError, polish
from open_typeless.models import ConfigRequest, LLMConfig, PromptMessages, STTConfig

_test_config = ConfigRequest(
    stt=STTConfig(
        api_base="https://api.test.com/v1",
        api_key="test-key",
        model="whisper-large-v3",
    ),
    llm=LLMConfig(
        api_base="https://api.test.com/v1",
        api_key="test-key",
        model="default-model",
    ),
)

_test_prompt = PromptMessages(system="You are helpful.", user="hello world")


def _chat_response(content: str) -> dict:
    return {"choices": [{"message": {"content": content}}]}


@pytest.fixture(autouse=True)
def _reset_config(monkeypatch):
    import open_typeless.config as cfg

    monkeypatch.setattr(cfg, "_config", None)


@pytest.mark.asyncio
async def test_polish_success(monkeypatch) -> None:
    set_config(_test_config)

    async def mock_post(self, url, **kwargs):
        return httpx.Response(200, json=_chat_response("Hello, world!"))

    monkeypatch.setattr(httpx.AsyncClient, "post", mock_post)
    result = await polish(_test_prompt)
    assert result == "Hello, world!"


@pytest.mark.asyncio
async def test_polish_not_configured() -> None:
    with pytest.raises(LLMError, match="not configured"):
        await polish(_test_prompt)


@pytest.mark.asyncio
async def test_polish_api_error(monkeypatch) -> None:
    set_config(_test_config)

    async def mock_post(self, url, **kwargs):
        return httpx.Response(500, text="Internal Server Error")

    monkeypatch.setattr(httpx.AsyncClient, "post", mock_post)
    with pytest.raises(LLMError, match="500"):
        await polish(_test_prompt)


@pytest.mark.asyncio
async def test_polish_timeout(monkeypatch) -> None:
    set_config(_test_config)

    async def mock_post(self, url, **kwargs):
        raise httpx.TimeoutException("timed out")

    monkeypatch.setattr(httpx.AsyncClient, "post", mock_post)
    with pytest.raises(LLMError, match="timed out"):
        await polish(_test_prompt)


@pytest.mark.asyncio
async def test_polish_model_override(monkeypatch) -> None:
    set_config(_test_config)
    captured = {}

    async def mock_post(self, url, **kwargs):
        captured["json"] = kwargs.get("json", {})
        return httpx.Response(200, json=_chat_response("result"))

    monkeypatch.setattr(httpx.AsyncClient, "post", mock_post)
    await polish(_test_prompt, model="custom/model-v2")
    assert captured["json"]["model"] == "custom/model-v2"


@pytest.mark.asyncio
async def test_polish_uses_default_model(monkeypatch) -> None:
    set_config(_test_config)
    captured = {}

    async def mock_post(self, url, **kwargs):
        captured["json"] = kwargs.get("json", {})
        return httpx.Response(200, json=_chat_response("result"))

    monkeypatch.setattr(httpx.AsyncClient, "post", mock_post)
    await polish(_test_prompt)
    assert captured["json"]["model"] == "default-model"
