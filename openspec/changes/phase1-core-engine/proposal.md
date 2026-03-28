## Why

OpenTypeless needs a core engine that handles the voice-to-text pipeline: receive audio from clients, transcribe via cloud STT, polish via LLM with scene-aware prompts, and return polished text. This is the foundation that all client implementations (macOS, Windows, Linux) will connect to. Without the engine, no client can function.

## What Changes

- Create a Python package (`open_typeless`) with HTTP server on `localhost:19823`
- Implement STT integration with Groq Whisper API for speech-to-text transcription
- Implement LLM integration with OpenRouter API for text polishing
- Build a 3-layer prompt system (system + scene context + user transcript) with YAML-based templates
- Implement scene detection logic that maps app bundle ID / window title to scene types (email, chat, ai_chat, document, code, default)
- Expose the full polish pipeline via `POST /polish` endpoint (audio in → polished text out)
- Add `GET /health` endpoint for client connectivity checks
- Add `GET/POST /contexts` endpoints for viewing/updating scene rules
- Provide a CLI entry point (`open-typeless serve`) to start the server
- Add unit and integration tests with mocked API calls

## Capabilities

### New Capabilities
- `http-server`: Local HTTP server on localhost:19823 with health check, serving as the engine's communication interface
- `stt-transcription`: Cloud STT integration (Groq Whisper) that converts audio bytes to raw transcript text
- `llm-polishing`: OpenRouter LLM integration that takes assembled prompts and returns polished text
- `prompt-routing`: Scene detection from app context + 3-layer prompt assembly with YAML-based templates
- `polish-pipeline`: Full end-to-end pipeline wiring: audio → STT → prompt assembly → LLM → response via POST /polish

### Modified Capabilities
_(none — this is a greenfield engine)_

## Impact

- **New code**: `engine/` directory with Python package, ~8 source files + tests
- **Dependencies**: fastapi, uvicorn, httpx, pyyaml, pydantic, python-multipart
- **External APIs**: Groq (STT), OpenRouter (LLM) — requires API keys via environment variables (`GROQ_API_KEY`, `OPENROUTER_API_KEY`)
- **Port**: Binds to localhost:19823 — future macOS client will connect here
