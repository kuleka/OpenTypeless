"""Integration tests for the HTTP server using FastAPI TestClient."""

import base64
from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

from open_typeless.server import app

client = TestClient(app)

_valid_config = {
    "stt": {
        "api_base": "https://api.test.com/v1",
        "api_key": "gsk_test1234abcd",
        "model": "whisper-large-v3",
    },
    "llm": {
        "api_base": "https://api.test.com/v1",
        "api_key": "sk-or-test5678efgh",
        "model": "test-model",
    },
}

_valid_audio = base64.b64encode(b"fake-wav-audio-data").decode()


@pytest.fixture(autouse=True)
def _reset_config(monkeypatch):
    import open_typeless.config as cfg

    monkeypatch.setattr(cfg, "_config", None)


# ── GET /health ────────────────────────────────────────


def test_health() -> None:
    resp = client.get("/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "ok"
    assert "version" in data


# ── POST /config ───────────────────────────────────────


def test_post_config() -> None:
    resp = client.post("/config", json=_valid_config)
    assert resp.status_code == 200
    assert resp.json()["status"] == "configured"


def test_post_config_with_default_language() -> None:
    config_with_lang = {**_valid_config, "default_language": "zh"}
    resp = client.post("/config", json=config_with_lang)
    assert resp.status_code == 200


def test_post_config_llm_only() -> None:
    resp = client.post("/config", json={"llm": _valid_config["llm"]})
    assert resp.status_code == 200
    assert resp.json()["status"] == "configured"


# ── GET /config ────────────────────────────────────────


def test_get_config_not_configured() -> None:
    resp = client.get("/config")
    assert resp.status_code == 200
    data = resp.json()
    assert data["configured"] is False
    assert data["stt"] is None
    assert data["llm"] is None
    assert data["default_language"] == "auto"


def test_get_config_configured() -> None:
    client.post("/config", json=_valid_config)
    resp = client.get("/config")
    assert resp.status_code == 200
    data = resp.json()
    assert data["configured"] is True
    assert "****" in data["stt"]["api_key"]
    assert "****" in data["llm"]["api_key"]


# ── POST /polish ───────────────────────────────────────


def test_polish_not_configured() -> None:
    resp = client.post(
        "/polish",
        json={"audio_base64": _valid_audio, "context": {"app_id": "com.apple.mail"}},
    )
    assert resp.status_code == 503
    assert resp.json()["error"]["code"] == "NOT_CONFIGURED"


def test_polish_invalid_base64() -> None:
    client.post("/config", json=_valid_config)
    resp = client.post("/polish", json={"audio_base64": "not-valid-base64!!!"})
    assert resp.status_code == 400
    assert resp.json()["error"]["code"] == "INVALID_AUDIO"


@patch("open_typeless.server.transcribe", new_callable=AsyncMock)
@patch("open_typeless.server.polish", new_callable=AsyncMock)
def test_polish_success(mock_polish, mock_transcribe) -> None:
    mock_transcribe.return_value = "hello world"
    mock_polish.return_value = "Hello, world!"

    client.post("/config", json=_valid_config)
    resp = client.post(
        "/polish",
        json={
            "audio_base64": _valid_audio,
            "context": {"app_id": "com.apple.mail", "window_title": "Compose"},
        },
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["text"] == "Hello, world!"
    assert data["raw_transcript"] == "hello world"
    assert data["task"] == "polish"
    assert data["context_detected"] == "email"
    assert data["model_used"] == "test-model"
    assert "stt_ms" in data
    assert "llm_ms" in data
    assert "total_ms" in data


@patch("open_typeless.server.transcribe", new_callable=AsyncMock)
@patch("open_typeless.server.polish", new_callable=AsyncMock)
def test_polish_translate_task(mock_polish, mock_transcribe) -> None:
    mock_transcribe.return_value = "你好世界"
    mock_polish.return_value = "Hello world"

    client.post("/config", json=_valid_config)
    resp = client.post(
        "/polish",
        json={
            "audio_base64": _valid_audio,
            "options": {"task": "translate", "output_language": "en"},
        },
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["task"] == "translate"
    assert data["text"] == "Hello world"


def test_polish_translate_missing_output_language() -> None:
    client.post("/config", json=_valid_config)
    resp = client.post(
        "/polish",
        json={
            "audio_base64": _valid_audio,
            "options": {"task": "translate"},
        },
    )
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "VALIDATION_ERROR"
    assert "output_language" in resp.json()["error"]["message"]


@patch("open_typeless.server.transcribe", new_callable=AsyncMock)
@patch("open_typeless.server.polish", new_callable=AsyncMock)
def test_polish_text_mode(mock_polish, mock_transcribe) -> None:
    mock_polish.return_value = "Hello, world!"

    client.post("/config", json=_valid_config)
    resp = client.post(
        "/polish",
        json={
            "text": "hello world",
            "context": {"app_id": "com.apple.mail", "window_title": "Compose"},
        },
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["text"] == "Hello, world!"
    assert data["raw_transcript"] == "hello world"
    assert data["stt_ms"] == 0
    assert data["context_detected"] == "email"
    mock_transcribe.assert_not_called()


@patch("open_typeless.server.transcribe", new_callable=AsyncMock)
@patch("open_typeless.server.polish", new_callable=AsyncMock)
def test_polish_text_mode_llm_only_config(mock_polish, mock_transcribe) -> None:
    """Text mode works even without STT configured."""
    mock_polish.return_value = "Polished text"

    client.post("/config", json={"llm": _valid_config["llm"]})
    resp = client.post("/polish", json={"text": "some transcript"})
    assert resp.status_code == 200
    assert resp.json()["text"] == "Polished text"
    mock_transcribe.assert_not_called()


def test_polish_neither_text_nor_audio() -> None:
    client.post("/config", json=_valid_config)
    resp = client.post("/polish", json={"context": {"app_id": "com.apple.mail"}})
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "VALIDATION_ERROR"
    assert "Either text or audio_base64" in resp.json()["error"]["message"]


def test_polish_both_text_and_audio() -> None:
    client.post("/config", json=_valid_config)
    resp = client.post(
        "/polish", json={"text": "hello", "audio_base64": _valid_audio}
    )
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "VALIDATION_ERROR"
    assert "mutually exclusive" in resp.json()["error"]["message"]


def test_polish_audio_without_stt_config() -> None:
    client.post("/config", json={"llm": _valid_config["llm"]})
    resp = client.post("/polish", json={"audio_base64": _valid_audio})
    assert resp.status_code == 503
    assert resp.json()["error"]["code"] == "STT_NOT_CONFIGURED"


from open_typeless.stt import STTError


@patch("open_typeless.server.transcribe", new_callable=AsyncMock)
def test_polish_stt_failure(mock_transcribe) -> None:
    mock_transcribe.side_effect = STTError("STT API failed")

    client.post("/config", json=_valid_config)
    resp = client.post("/polish", json={"audio_base64": _valid_audio})
    assert resp.status_code == 502
    assert resp.json()["error"]["code"] == "STT_FAILURE"


from open_typeless.llm import LLMError


@patch("open_typeless.server.transcribe", new_callable=AsyncMock)
@patch("open_typeless.server.polish", new_callable=AsyncMock)
def test_polish_llm_failure(mock_polish, mock_transcribe) -> None:
    mock_transcribe.return_value = "hello"
    mock_polish.side_effect = LLMError("LLM API failed")

    client.post("/config", json=_valid_config)
    resp = client.post("/polish", json={"audio_base64": _valid_audio})
    assert resp.status_code == 502
    assert resp.json()["error"]["code"] == "LLM_FAILURE"


# ── GET /contexts ──────────────────────────────────────


def test_get_contexts() -> None:
    resp = client.get("/contexts")
    assert resp.status_code == 200
    data = resp.json()
    assert "contexts" in data
    assert "email" in data["contexts"]
    assert "default" in data["contexts"]


# ── POST /contexts ─────────────────────────────────────


def test_post_contexts() -> None:
    resp = client.post(
        "/contexts",
        json={
            "scene": "email",
            "match_rules": {
                "app_ids": ["com.custom.mail"],
                "window_title_contains": ["CustomMail"],
            },
        },
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "updated"
    assert resp.json()["scene"] == "email"


# ── POST /transcribe ──────────────────────────────────


@patch("open_typeless.server.transcribe", new_callable=AsyncMock)
def test_transcribe_success(mock_transcribe) -> None:
    mock_transcribe.return_value = "hello world"

    client.post("/config", json=_valid_config)
    resp = client.post(
        "/transcribe",
        files={"file": ("audio.wav", b"fake-wav-data", "audio/wav")},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["text"] == "hello world"
    assert "stt_ms" in data


@patch("open_typeless.server.transcribe", new_callable=AsyncMock)
def test_transcribe_with_language(mock_transcribe) -> None:
    mock_transcribe.return_value = "你好"

    client.post("/config", json=_valid_config)
    resp = client.post(
        "/transcribe",
        files={"file": ("audio.wav", b"fake-wav-data", "audio/wav")},
        data={"language": "zh"},
    )
    assert resp.status_code == 200
    assert resp.json()["text"] == "你好"
    mock_transcribe.assert_called_once_with(b"fake-wav-data", language="zh")


def test_transcribe_stt_not_configured() -> None:
    client.post("/config", json={"llm": _valid_config["llm"]})
    resp = client.post(
        "/transcribe",
        files={"file": ("audio.wav", b"fake-wav-data", "audio/wav")},
    )
    assert resp.status_code == 503
    assert resp.json()["error"]["code"] == "STT_NOT_CONFIGURED"


@patch("open_typeless.server.transcribe", new_callable=AsyncMock)
def test_transcribe_stt_failure(mock_transcribe) -> None:
    mock_transcribe.side_effect = STTError("STT API failed")

    client.post("/config", json=_valid_config)
    resp = client.post(
        "/transcribe",
        files={"file": ("audio.wav", b"fake-wav-data", "audio/wav")},
    )
    assert resp.status_code == 502
    assert resp.json()["error"]["code"] == "STT_FAILURE"
