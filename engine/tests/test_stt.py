"""Tests for STT integration with mocked API responses."""

import httpx
import pytest

from open_typeless.config import set_config
from open_typeless.models import ConfigRequest, LLMConfig, STTConfig
from open_typeless.stt import STTError, transcribe

_test_config = ConfigRequest(
    stt=STTConfig(
        api_base="https://api.test.com/v1",
        api_key="test-key",
        model="whisper-large-v3",
    ),
    llm=LLMConfig(
        api_base="https://api.test.com/v1",
        api_key="test-key",
        model="test-model",
    ),
)


@pytest.fixture(autouse=True)
def _reset_config(monkeypatch):
    import open_typeless.config as cfg

    monkeypatch.setattr(cfg, "_config", None)


@pytest.mark.asyncio
async def test_transcribe_success(monkeypatch) -> None:
    set_config(_test_config)

    async def mock_post(self, url, **kwargs):
        resp = httpx.Response(200, json={"text": "hello world"})
        return resp

    monkeypatch.setattr(httpx.AsyncClient, "post", mock_post)
    result = await transcribe(b"fake-audio-bytes")
    assert result == "hello world"


@pytest.mark.asyncio
async def test_transcribe_not_configured() -> None:
    with pytest.raises(STTError, match="not configured"):
        await transcribe(b"fake-audio-bytes")


@pytest.mark.asyncio
async def test_transcribe_stt_not_in_config() -> None:
    """Config exists but stt is None (LLM-only mode)."""
    llm_only = ConfigRequest(
        llm=LLMConfig(
            api_base="https://api.test.com/v1",
            api_key="test-key",
            model="test-model",
        ),
    )
    set_config(llm_only)
    with pytest.raises(STTError, match="not configured"):
        await transcribe(b"fake-audio-bytes")


@pytest.mark.asyncio
async def test_transcribe_api_error(monkeypatch) -> None:
    set_config(_test_config)

    async def mock_post(self, url, **kwargs):
        return httpx.Response(500, text="Internal Server Error")

    monkeypatch.setattr(httpx.AsyncClient, "post", mock_post)
    with pytest.raises(STTError, match="500"):
        await transcribe(b"fake-audio-bytes")


@pytest.mark.asyncio
async def test_transcribe_timeout(monkeypatch) -> None:
    set_config(_test_config)

    async def mock_post(self, url, **kwargs):
        raise httpx.TimeoutException("timed out")

    monkeypatch.setattr(httpx.AsyncClient, "post", mock_post)
    with pytest.raises(STTError, match="timed out"):
        await transcribe(b"fake-audio-bytes")


@pytest.mark.asyncio
async def test_transcribe_with_language(monkeypatch) -> None:
    set_config(_test_config)
    captured = {}

    async def mock_post(self, url, **kwargs):
        captured["data"] = kwargs.get("data", {})
        return httpx.Response(200, json={"text": "你好"})

    monkeypatch.setattr(httpx.AsyncClient, "post", mock_post)
    result = await transcribe(b"fake-audio-bytes", language="zh")
    assert result == "你好"
    assert captured["data"]["language"] == "zh"
