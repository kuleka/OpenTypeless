"""FastAPI HTTP server — all endpoints."""

import base64
import time
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI, File, Form, UploadFile
from fastapi.responses import JSONResponse

from . import __version__
from .config import get_masked_config, is_configured, is_stt_configured, set_config
from .context import assemble_prompt
from .llm import LLMError, polish
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
    SceneConfig,
    TaskType,
    TranscribeResponse,
    UpdateContextRequest,
)
from .prompt_router import detect_scene, get_all_scene_configs, load_prompts
from .stt import STTError, transcribe

# In-memory scene config overrides (updated via POST /contexts)
_context_overrides: dict[str, SceneConfig] = {}


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
    load_prompts()
    yield


app = FastAPI(title="OpenTypeless Engine", version=__version__, lifespan=lifespan)


# ── GET /health ────────────────────────────────────────


@app.get("/health", response_model=HealthResponse)
async def health() -> HealthResponse:
    return HealthResponse(version=__version__)


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
    if not is_stt_configured():
        return _error(
            503,
            "STT_NOT_CONFIGURED",
            "STT is not configured. Call POST /config with stt settings first, or use local STT on the client.",
        )

    audio_bytes = await file.read()

    stt_start = time.perf_counter()
    try:
        text = await transcribe(audio_bytes, language=language)
    except STTError as e:
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
    # Check configuration
    if not is_configured():
        return _error(503, "NOT_CONFIGURED", "Engine is not configured. Call POST /config first.")

    # Validate input: text and audio_base64 are mutually exclusive
    if req.text is None and req.audio_base64 is None:
        return _error(422, "VALIDATION_ERROR", "Either text or audio_base64 must be provided")
    if req.text is not None and req.audio_base64 is not None:
        return _error(422, "VALIDATION_ERROR", "text and audio_base64 are mutually exclusive")

    # Validate task
    if req.options.task == TaskType.TRANSLATE and not req.options.output_language:
        return _error(422, "VALIDATION_ERROR", "output_language is required when task is translate")

    from .config import get_config

    config = get_config()
    assert config is not None

    total_start = time.perf_counter()
    stt_ms = 0

    if req.text is not None:
        # Text mode: skip STT
        raw_transcript = req.text
    else:
        # Audio mode: need STT
        if not is_stt_configured():
            return _error(
                503,
                "STT_NOT_CONFIGURED",
                "STT is not configured. Call POST /config with stt settings first, or use local STT on the client.",
            )

        try:
            audio_bytes = base64.b64decode(req.audio_base64, validate=True)
        except Exception:
            return _error(400, "INVALID_AUDIO", "audio_base64 is not valid base64 data")

        language = req.options.language or config.default_language

        stt_start = time.perf_counter()
        try:
            raw_transcript = await transcribe(audio_bytes, language=language)
        except STTError as e:
            return _error(502, "STT_FAILURE", str(e))
        stt_ms = int((time.perf_counter() - stt_start) * 1000)

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
        polished_text = await polish(prompt, model=model_override)
    except LLMError as e:
        return _error(502, "LLM_FAILURE", str(e))
    llm_ms = int((time.perf_counter() - llm_start) * 1000)

    total_ms = int((time.perf_counter() - total_start) * 1000)

    return PolishResponse(
        text=polished_text,
        raw_transcript=raw_transcript,
        task=req.options.task.value,
        context_detected=scene.value,
        model_used=model_override or config.llm.model,
        stt_ms=stt_ms,
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
