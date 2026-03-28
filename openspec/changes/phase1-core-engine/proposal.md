## Why

OpenTypeless needs a core engine that handles the voice-to-text pipeline: receive audio from clients, transcribe via cloud STT, polish via LLM with scene-aware prompts, and return polished text. This is the foundation that all client implementations (macOS, Windows, Linux) will connect to. Without the engine, no client can function.

## What Changes

- Create a Python package (`open_typeless`) with HTTP server on `localhost:19823`
- Implement provider-agnostic STT integration (any OpenAI Whisper-compatible API) for speech-to-text transcription
- Implement provider-agnostic LLM integration (any OpenAI Chat Completions-compatible API) for text polishing
- Add `POST /config` and `GET /config` endpoints for client to push API connection info (api_base, api_key, model for both STT and LLM)
- Build a 3-layer prompt system (system + scene context + user transcript) with YAML-based templates
- Implement scene detection logic that maps app bundle ID / window title to scene types (email, chat, ai_chat, document, code, default)
- Expose the full polish pipeline via `POST /polish` endpoint (audio in → polished text out)
- Add `GET /health` endpoint for client connectivity checks
- Add `GET/POST /config` endpoints for API key and service configuration
- Add `GET/POST /contexts` endpoints for viewing/updating scene rules
- Provide a CLI entry point (`open-typeless serve`) to start the server
- Add unit and integration tests with mocked API calls

## Capabilities

### New Capabilities
- `http-server`: Local HTTP server on localhost:19823 with health check and config endpoint, serving as the engine's communication interface
- `stt-transcription`: Provider-agnostic STT integration (any OpenAI Whisper-compatible API) that converts audio bytes to raw transcript text
- `llm-polishing`: Provider-agnostic LLM integration (any OpenAI Chat Completions-compatible API) that takes assembled prompts and returns polished text
- `prompt-routing`: Scene detection from app context + 3-layer prompt assembly with YAML-based templates
- `polish-pipeline`: Full end-to-end pipeline wiring: audio → STT → prompt assembly → LLM → response via POST /polish

### Modified Capabilities
_(none — this is a greenfield engine)_

## Impact

- **New code**: `engine/` directory with Python package, ~9 source files + tests
- **Dependencies**: fastapi, uvicorn, httpx, pyyaml, pydantic, python-multipart
- **External APIs**: Any OpenAI-compatible STT and LLM APIs — connection info (api_base, api_key, model) provided by client via `POST /config`
- **Port**: Binds to localhost:19823 — future macOS client will connect here
