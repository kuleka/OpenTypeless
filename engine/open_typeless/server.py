"""FastAPI HTTP server — all endpoints."""

import os
import time
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from dataclasses import dataclass, field
from datetime import datetime, timezone

from fastapi import FastAPI, File, Form, UploadFile
from fastapi.responses import JSONResponse

from . import __version__
from .config import get_masked_config, is_configured, is_stt_configured, set_config
from .context import assemble_prompt
from . import llm as _llm_mod
from . import stt as _stt_mod
from .llm import LLMError
from .models import (
    AppContext,
    ConfigRequest,
    ConfigResponse,
    ErrorDetail,
    ErrorResponse,
    HealthResponse,
    MatchRule,
    PolishRequest,
    PolishResponse,
    RequestStats,
    SceneConfig,
    TaskType,
    TranscribeResponse,
    UpdateContextRequest,
)
from .prompt_router import detect_scene, get_all_scene_configs, load_prompts
from .stt import STTError

# In-memory scene config overrides (updated via POST /contexts)
_context_overrides: dict[str, SceneConfig] = {}


@dataclass
class _EngineStats:
    requests_total: int = 0
    requests_failed: int = 0
    last_request_at: str | None = None


_stats = _EngineStats()
_start_time: float = 0.0


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
    global _start_time
    _start_time = time.time()
    load_prompts()

    if os.environ.get("OPEN_TYPELESS_STUB") == "1":

        async def _stub_polish(prompt, model=None):  # noqa: ARG001
            return f"[stub] {prompt.user}"

        async def _stub_transcribe(audio_bytes, language="auto"):  # noqa: ARG001
            return "stub transcription"

        _llm_mod.polish = _stub_polish  # type: ignore[assignment]
        _stt_mod.transcribe = _stub_transcribe  # type: ignore[assignment]

    yield


app = FastAPI(title="OpenTypeless Engine", version=__version__, lifespan=lifespan)


# ── GET /health ────────────────────────────────────────


@app.get("/health", response_model=HealthResponse)
async def health() -> HealthResponse:
    return HealthResponse(
        version=__version__,
        configured=is_configured(),
        stt_configured=is_stt_configured(),
        uptime_seconds=int(time.time() - _start_time) if _start_time else 0,
        stats=RequestStats(
            requests_total=_stats.requests_total,
            requests_failed=_stats.requests_failed,
            last_request_at=_stats.last_request_at,
        ),
    )


# ── POST /config ───────────────────────────────────────


@app.post("/config")
async def post_config(config: ConfigRequest) -> dict[str, str]:
    set_config(config)
    return {"status": "configured"}


# ── GET /config ────────────────────────────────────────


@app.get("/config", response_model=ConfigResponse)
async def get_config_endpoint() -> ConfigResponse:
    return get_masked_config()


# ── POST /transcribe ──────────────────────────────────


@app.post("/transcribe", response_model=TranscribeResponse)
async def post_transcribe(
    file: UploadFile = File(...),
    language: str = Form("auto"),
) -> JSONResponse | TranscribeResponse:
    _stats.requests_total += 1
    _stats.last_request_at = datetime.now(timezone.utc).isoformat()

    if not is_stt_configured():
        _stats.requests_failed += 1
        return _error(
            503,
            "STT_NOT_CONFIGURED",
            "STT is not configured. Call POST /config with stt settings first, or use local STT on the client.",
        )

    audio_bytes = await file.read()

    stt_start = time.perf_counter()
    try:
        text = await _stt_mod.transcribe(audio_bytes, language=language)
    except STTError as e:
        _stats.requests_failed += 1
        return _error(502, "STT_FAILURE", str(e))
    stt_ms = int((time.perf_counter() - stt_start) * 1000)

    return TranscribeResponse(
        text=text,
        language_detected=language if language != "auto" else "unknown",
        duration_ms=0,
        stt_ms=stt_ms,
    )


# ── POST /polish ───────────────────────────────────────


@app.post("/polish", response_model=PolishResponse)
async def post_polish(req: PolishRequest) -> JSONResponse | PolishResponse:
    _stats.requests_total += 1
    _stats.last_request_at = datetime.now(timezone.utc).isoformat()

    # Check configuration
    if not is_configured():
        _stats.requests_failed += 1
        return _error(503, "NOT_CONFIGURED", "Engine is not configured. Call POST /config first.")

    # Validate task
    if req.options.task == TaskType.TRANSLATE and not req.options.output_language:
        _stats.requests_failed += 1
        return _error(422, "VALIDATION_ERROR", "output_language is required when task is translate")

    from .config import get_config

    config = get_config()
    assert config is not None

    total_start = time.perf_counter()
    raw_transcript = req.text

    # Scene detection
    scene = detect_scene(
        req.context.app_id,
        req.context.window_title,
        overrides=_context_overrides,
    )

    # Prompt assembly
    prompt = assemble_prompt(
        scene,
        raw_transcript,
        task=req.options.task,
        output_language=req.options.output_language,
    )

    # LLM
    model_override = req.options.model
    llm_start = time.perf_counter()
    try:
        polished_text = await _llm_mod.polish(prompt, model=model_override)
    except LLMError as e:
        _stats.requests_failed += 1
        return _error(502, "LLM_FAILURE", str(e))
    llm_ms = int((time.perf_counter() - llm_start) * 1000)

    total_ms = int((time.perf_counter() - total_start) * 1000)

    return PolishResponse(
        text=polished_text,
        raw_transcript=raw_transcript,
        task=req.options.task.value,
        context_detected=scene.value,
        model_used=model_override or config.llm.model,
        llm_ms=llm_ms,
        total_ms=total_ms,
    )


# ── GET /contexts ──────────────────────────────────────


@app.get("/contexts")
async def get_contexts() -> dict:
    configs = get_all_scene_configs(overrides=_context_overrides)
    return {"contexts": {k: v.model_dump() for k, v in configs.items()}}


# ── POST /contexts ─────────────────────────────────────


@app.post("/contexts")
async def post_contexts(req: UpdateContextRequest) -> dict:
    _context_overrides[req.scene] = SceneConfig(match_rules=req.match_rules)
    return {"status": "updated", "scene": req.scene}


# ── Helpers ────────────────────────────────────────────


def _error(status_code: int, code: str, message: str) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content=ErrorResponse(error=ErrorDetail(code=code, message=message)).model_dump(),
    )
