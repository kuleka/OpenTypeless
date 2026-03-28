## Context

OpenTypeless is a new project with no existing engine code. The macOS client (based on Pindrop) exists but currently uses local WhisperKit for transcription. We need to build a Python HTTP engine that clients connect to for cloud STT + LLM polishing.

The engine must be simple, fast to start, and easy to install via `pip`. All heavy lifting (STT, LLM) happens on cloud APIs — the engine is essentially a pipeline orchestrator.

## Goals / Non-Goals

**Goals:**
- Fully functional polish pipeline: audio → STT → prompt assembly → LLM → polished text
- HTTP API on localhost:19823 that any client can connect to
- Scene-aware prompt routing based on app context
- Latency breakdown in responses for debugging
- Installable via `pip install -e .` with a `open-typeless serve` CLI command
- Testable without real API keys (mocked tests)

**Non-Goals:**
- WebSocket streaming audio (Phase 3)
- Style memory / few-shot learning (Phase 3)
- Windows/Linux client support (Phase 2+)
- User authentication (local-only, no auth needed)
- Persistent storage of scene customizations (in-memory only for Phase 1)
- Audio preprocessing or format conversion

## Decisions

### 1. Web framework: FastAPI

**Choice**: FastAPI with uvicorn

**Why**: Async-native (good for concurrent API calls to STT/LLM), automatic OpenAPI docs, Pydantic integration for request/response validation. Lightweight enough for a local service.

**Alternatives considered**:
- Flask — synchronous by default, would need additional async setup
- Starlette — FastAPI is built on it, adds convenient features for free

### 2. HTTP client: httpx

**Choice**: httpx with async support

**Why**: Native async/await, compatible with FastAPI's async handlers. Clean API for multipart uploads (needed for STT) and JSON requests (needed for LLM).

**Alternatives considered**:
- requests — no native async, would block the event loop
- aiohttp — works but httpx has better ergonomics

### 3. Audio input format: base64 in JSON body

**Choice**: Client sends audio as base64-encoded string in JSON request body.

**Why**: Simpler than multipart form uploads. The engine decodes base64 → bytes, then sends as multipart to Groq. Audio files for voice dictation are small (10-30 seconds = 100-500KB), so base64 overhead (~33%) is negligible.

**Alternatives considered**:
- Multipart form upload from client — more complex client code, marginal benefit for small files

### 4. Configuration: environment variables only

**Choice**: API keys and basic config via env vars (`GROQ_API_KEY`, `OPENROUTER_API_KEY`, `OPEN_TYPELESS_PORT`).

**Why**: Simplest possible setup. No config file to manage. Works everywhere (Docker, systemd, shell).

**Alternatives considered**:
- YAML/TOML config file — overkill for 3-4 settings in Phase 1
- CLI flags — less convenient for repeated use

### 5. Prompt templates: single YAML file loaded at startup

**Choice**: `prompts/defaults.yaml` contains system prompt + all scene prompts + match rules. Loaded once at server start, cached in memory.

**Why**: Easy to read, edit, and version control. No database needed. Users can customize by editing the file or using `POST /contexts` to update in-memory.

### 6. Scene detection: first-match-wins with ordered rules

**Choice**: Iterate through scenes in defined order. Each scene has match rules (app_id exact match or window_title substring match). First matching scene wins. Fall back to `default`.

**Why**: Simple, predictable, debuggable. The project plan uses this approach and it matches Typeless's behavior.

### 7. Prompt assembly: system + context as single system message

**Choice**: Combine system prompt and scene context prompt into one `system` role message, send raw transcript as `user` role message.

**Why**: Many LLM models on OpenRouter only support a single system message. Combining avoids compatibility issues while preserving the 3-layer conceptual architecture.

### 8. Data models: centralized in models.py

**Choice**: All Pydantic models in a single `models.py` file.

**Why**: Prevents circular imports, makes the API contract clear in one place. The total model count is small (~8 models).

## Risks / Trade-offs

**[Groq API availability]** → If Groq is down, the entire pipeline fails.
*Mitigation*: Clear error messages. Deepgram fallback can be added later without architectural changes since `stt.py` abstracts the provider.

**[OpenRouter model changes]** → Models may be deprecated or pricing may change.
*Mitigation*: Model is configurable per request. Default can be updated in `defaults.yaml`.

**[Base64 audio size]** → Very long recordings (>60s) produce large JSON payloads.
*Mitigation*: Acceptable for Phase 1. Voice dictation segments are typically 5-30 seconds. Can add multipart upload in Phase 3 if needed.

**[In-memory prompt customization]** → `POST /contexts` changes are lost on restart.
*Mitigation*: Acceptable for Phase 1. Users can edit `defaults.yaml` directly for persistent changes.

**[Port conflict]** → Port 19823 may be in use.
*Mitigation*: Configurable via `OPEN_TYPELESS_PORT` env var. Server logs a clear error if port is occupied.
