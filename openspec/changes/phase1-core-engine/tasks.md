## 1. Project Bootstrap

- [ ] 1.1 Create `engine/pyproject.toml` with package metadata, dependencies (fastapi, uvicorn, httpx, pyyaml, pydantic, python-multipart), and dev dependencies (pytest, pytest-asyncio)
- [ ] 1.2 Create `engine/open_typeless/__init__.py` with version string
- [ ] 1.3 Create `engine/open_typeless/models.py` with all Pydantic models (AppContext, PolishRequest, PolishResponse, HealthResponse, SceneType, MatchRule, SceneConfig, PromptMessages)
- [ ] 1.4 Verify `pip install -e ".[dev]"` succeeds in the engine directory

## 2. Prompt Templates and Router

- [ ] 2.1 Create `engine/open_typeless/prompts/defaults.yaml` with system prompt + 6 scene templates (email, chat, ai_chat, document, code, default) and match rules
- [ ] 2.2 Implement `engine/open_typeless/prompt_router.py` with `load_prompts()`, `detect_scene()`, and `get_scene_config()` functions
- [ ] 2.3 Write `engine/tests/test_prompt_router.py` — test scene detection for all app_id and window_title match cases, default fallback, and YAML loading

## 3. Context Assembler

- [ ] 3.1 Implement `engine/open_typeless/context.py` with `assemble_prompt(scene, raw_transcript) -> PromptMessages` that builds the 3-layer prompt
- [ ] 3.2 Write `engine/tests/test_context.py` — test correct assembly for each scene type, verify system prompt is always present

## 4. STT Integration

- [ ] 4.1 Implement `engine/open_typeless/stt.py` with async `transcribe()` function calling Groq Whisper API via httpx
- [ ] 4.2 Write `engine/tests/test_stt.py` — mock Groq API responses, test success, error handling, missing API key, and timeout cases

## 5. LLM Integration

- [ ] 5.1 Implement `engine/open_typeless/llm.py` with async `polish()` function calling OpenRouter API via httpx
- [ ] 5.2 Write `engine/tests/test_llm.py` — mock OpenRouter API responses, test success, error handling, missing API key, and timeout cases

## 6. HTTP Server and Full Pipeline

- [ ] 6.1 Implement `engine/open_typeless/server.py` with FastAPI app: `GET /health`, `POST /polish`, `GET /contexts`, `POST /contexts`
- [ ] 6.2 Wire the full pipeline in `POST /polish`: decode base64 → STT → detect scene → assemble prompt → LLM → return PolishResponse with latency
- [ ] 6.3 Add error handling for pipeline failures (STT error → 502, LLM error → 502, invalid base64 → 400)
- [ ] 6.4 Write `engine/tests/test_server.py` — integration tests using FastAPI TestClient with mocked STT/LLM, test all endpoints

## 7. CLI Entry Point

- [ ] 7.1 Implement `engine/open_typeless/cli.py` with `open-typeless serve` command (starts uvicorn) and `--port` flag
- [ ] 7.2 Add `[project.scripts]` entry in pyproject.toml pointing to CLI

## 8. End-to-End Verification

- [ ] 8.1 Run full test suite with `pytest` — all tests pass
- [ ] 8.2 Manual verification: start server with `open-typeless serve`, confirm `curl localhost:19823/health` returns 200
