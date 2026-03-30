## 1. Project Bootstrap

- [x] 1.1 Create `engine/pyproject.toml` with package metadata, dependencies (fastapi, uvicorn, httpx, pyyaml, pydantic, python-multipart), and dev dependencies (pytest, pytest-asyncio)
- [x] 1.2 Create `engine/open_typeless/__init__.py` with version string
- [x] 1.3 Create `engine/open_typeless/models.py` with all Pydantic models (STTConfig, LLMConfig, EngineConfig, AppContext, PolishRequest, PolishResponse, HealthResponse, ConfigRequest, ConfigResponse, SceneType, MatchRule, SceneConfig, PromptMessages)
- [x] 1.4 Verify `pip install -e ".[dev]"` succeeds in the engine directory

## 2. Prompt Templates and Router

- [x] 2.1 Create `engine/open_typeless/prompts/defaults.yaml` with system prompt + 6 scene templates (email, chat, ai_chat, document, code, default) and match rules
- [x] 2.2 Implement `engine/open_typeless/prompt_router.py` with `load_prompts()`, `detect_scene()`, and `get_scene_config()` functions
- [x] 2.3 Write `engine/tests/test_prompt_router.py` — test scene detection for all app_id and window_title match cases, default fallback, and YAML loading

## 3. Context Assembler

- [x] 3.1 Implement `engine/open_typeless/context.py` with `assemble_prompt(scene, raw_transcript) -> PromptMessages` that builds the 3-layer prompt
- [x] 3.2 Write `engine/tests/test_context.py` — test correct assembly for each scene type, verify system prompt is always present

## 4. Configuration Management

- [x] 4.1 Implement `engine/open_typeless/config.py` with in-memory config store: `set_config(config)`, `get_config()`, `is_configured()`, and `mask_api_key(key)` functions
- [x] 4.2 Write `engine/tests/test_config.py` — test config storage, retrieval, configured state check, and API key masking

## 5. STT Integration

- [x] 5.1 Implement `engine/open_typeless/stt.py` with async `transcribe()` function that calls `{stt.api_base}/audio/transcriptions` using the configured api_key and model via httpx (provider-agnostic, any OpenAI Whisper-compatible API)
- [x] 5.2 Write `engine/tests/test_stt.py` ��� mock STT API responses, test success, error handling, not-configured state, and timeout cases

## 6. LLM Integration

- [x] 6.1 Implement `engine/open_typeless/llm.py` with async `polish()` function that calls `{llm.api_base}/chat/completions` using the configured api_key and model via httpx (provider-agnostic, any OpenAI Chat Completions-compatible API)
- [x] 6.2 Write `engine/tests/test_llm.py` — mock LLM API responses, test success, error handling, not-configured state, per-request model override, and timeout cases

## 7. HTTP Server and Full Pipeline

- [x] 7.1 Implement `engine/open_typeless/server.py` with FastAPI app: `GET /health`, `POST /config`, `GET /config`, `POST /polish`, `GET /contexts`, `POST /contexts`
- [x] 7.2 Wire `POST /config` to store STT/LLM connection info in memory; wire `GET /config` to return masked config
- [x] 7.3 Wire the full pipeline in `POST /polish`: check config → decode base64 → STT → detect scene → assemble prompt → LLM → return PolishResponse with latency
- [x] 7.4 Add error handling: not configured → 503, STT error → 502, LLM error → 502, invalid base64 → 400
- [x] 7.5 Write `engine/tests/test_server.py` — integration tests using FastAPI TestClient with mocked STT/LLM, test all endpoints including /config and 503 when not configured

## 8. CLI Entry Point

- [x] 8.1 Implement `engine/open_typeless/cli.py` with `open-typeless serve` command (starts uvicorn) and `--port` flag
- [x] 8.2 Add `[project.scripts]` entry in pyproject.toml pointing to CLI

## 9. End-to-End Verification

- [x] 9.1 Run full test suite with `pytest` — all tests pass
- [x] 9.2 Manual verification: start server with `open-typeless serve`, call `POST /config` with test API keys, confirm `POST /polish` returns polished text
