"""Pydantic models for the OpenTypeless Engine API."""

from enum import Enum
from typing import Optional

from pydantic import BaseModel


# ── Enums ──────────────────────────────────────────────


class SceneType(str, Enum):
    EMAIL = "email"
    CHAT = "chat"
    AI_CHAT = "ai_chat"
    DOCUMENT = "document"
    CODE = "code"
    DEFAULT = "default"


class TaskType(str, Enum):
    POLISH = "polish"
    TRANSLATE = "translate"


# ── Config ─────────────────────────────────────────────


class STTConfig(BaseModel):
    api_base: str
    api_key: str
    model: str


class LLMConfig(BaseModel):
    api_base: str
    api_key: str
    model: str


class ConfigRequest(BaseModel):
    stt: Optional[STTConfig] = None
    llm: LLMConfig
    default_language: str = "auto"


class MaskedSTTConfig(BaseModel):
    api_base: str
    api_key: str  # masked
    model: str


class MaskedLLMConfig(BaseModel):
    api_base: str
    api_key: str  # masked
    model: str


class ConfigResponse(BaseModel):
    configured: bool
    stt: Optional[MaskedSTTConfig] = None
    llm: Optional[MaskedLLMConfig] = None
    default_language: str = "auto"


# ── Polish ─────────────────────────────────────────────


class AppContext(BaseModel):
    app_id: str = ""
    window_title: str = ""


class PolishOptions(BaseModel):
    task: TaskType = TaskType.POLISH
    language: Optional[str] = None  # None → use config default_language
    model: Optional[str] = None  # None → use config llm.model
    output_language: Optional[str] = None


class PolishRequest(BaseModel):
    text: Optional[str] = None
    audio_base64: Optional[str] = None
    audio_format: str = "wav"
    context: AppContext = AppContext()
    options: PolishOptions = PolishOptions()


class PolishResponse(BaseModel):
    text: str
    raw_transcript: str
    task: str
    context_detected: str
    model_used: str
    stt_ms: int
    llm_ms: int
    total_ms: int


# ── Transcribe ────────────────────────────────────────


class TranscribeResponse(BaseModel):
    text: str
    language_detected: str
    duration_ms: int
    stt_ms: int


# ── Health ─────────────────────────────────────────────


class HealthResponse(BaseModel):
    status: str = "ok"
    version: str


# ── Contexts ───────────────────────────────────────────


class MatchRule(BaseModel):
    app_ids: list[str] = []
    window_title_contains: list[str] = []


class SceneConfig(BaseModel):
    match_rules: MatchRule


class UpdateContextRequest(BaseModel):
    scene: str
    match_rules: MatchRule


# ── Prompt ─────────────────────────────────────────────


class PromptMessages(BaseModel):
    """The assembled prompt ready to send to the LLM."""

    system: str
    user: str


# ── Error ──────────────────────────────────────────────


class ErrorDetail(BaseModel):
    code: str
    message: str


class ErrorResponse(BaseModel):
    error: ErrorDetail
