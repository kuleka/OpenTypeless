"""Tests for configuration management."""

from open_typeless.config import (
    get_config,
    get_masked_config,
    is_configured,
    mask_api_key,
    set_config,
)
from open_typeless.models import ConfigRequest, LLMConfig, STTConfig

_test_config = ConfigRequest(
    stt=STTConfig(
        api_base="https://api.groq.com/openai/v1",
        api_key="gsk_test1234abcd",
        model="whisper-large-v3",
    ),
    llm=LLMConfig(
        api_base="https://openrouter.ai/api/v1",
        api_key="sk-or-test5678efgh",
        model="minimax/minimax-m2.7",
    ),
    default_language="auto",
)


# ── mask_api_key ──────────────────────────────────────


def test_mask_key_with_prefix() -> None:
    assert mask_api_key("gsk_abc123xyz") == "gsk_****3xyz"


def test_mask_key_with_double_prefix() -> None:
    assert mask_api_key("sk-or-abc123xyz") == "sk-or-****3xyz"


def test_mask_short_key() -> None:
    result = mask_api_key("abc")
    assert "****" in result


# ── Config store ──────────────────────────────────────


def test_not_configured_initially(monkeypatch) -> None:
    import open_typeless.config as cfg

    monkeypatch.setattr(cfg, "_config", None)
    assert not is_configured()
    assert get_config() is None


def test_set_and_get_config(monkeypatch) -> None:
    import open_typeless.config as cfg

    monkeypatch.setattr(cfg, "_config", None)
    set_config(_test_config)
    assert is_configured()
    assert get_config() is _test_config


# ── Masked config ─────────────────────────────────────


def test_masked_config_not_configured(monkeypatch) -> None:
    import open_typeless.config as cfg

    monkeypatch.setattr(cfg, "_config", None)
    result = get_masked_config()
    assert result.configured is False
    assert result.stt is None
    assert result.llm is None
    assert result.default_language == "auto"


def test_masked_config_configured(monkeypatch) -> None:
    import open_typeless.config as cfg

    monkeypatch.setattr(cfg, "_config", None)
    set_config(_test_config)
    result = get_masked_config()
    assert result.configured is True
    assert result.stt is not None
    assert "****" in result.stt.api_key
    assert "****" in result.llm.api_key
    assert result.default_language == "auto"
    # Original key should not appear
    assert "test1234abcd" not in result.stt.api_key
