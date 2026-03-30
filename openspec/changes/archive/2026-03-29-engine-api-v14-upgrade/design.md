## Context

Engine was built against API contract v1.3.0 where `audio_base64` was the only input to `/polish` and `stt` config was always required. The macOS client (now merged to main) upgraded the contract to v1.4.0 to support local STT mode (WhisperKit/Parakeet) where the client sends pre-transcribed text directly, bypassing Engine's STT. The engine code must be updated to match.

Current engine implementation:
- `POST /config` requires both `stt` and `llm`
- `POST /polish` requires `audio_base64`, always runs STT → LLM pipeline
- No `/transcribe` endpoint exists
- Single `NOT_CONFIGURED` error code covers all config issues

## Goals / Non-Goals

**Goals:**
- Engine fully implements API contract v1.4.0 as defined in `docs/api-contract.md`
- Backward-compatible audio mode still works (existing tests continue to pass with minor adjustments)
- New text-input mode for `/polish` enables local STT workflow
- Standalone `/transcribe` endpoint for independent STT access

**Non-Goals:**
- Streaming/WebSocket support (Phase 3)
- Client-side changes (already done)
- Changing prompt routing or LLM integration logic (unaffected)

## Decisions

### 1. PolishRequest uses Optional fields with custom validation
Rather than separate request models for text vs audio mode, use a single `PolishRequest` with both `text: Optional[str]` and `audio_base64: Optional[str]`, validated at the endpoint level (mutually exclusive, at least one required). This keeps the model simple and matches the API contract's single endpoint design.

**Alternative**: Two separate request models with a union type — rejected because FastAPI doesn't natively support discriminated unions in JSON body parsing without custom logic.

### 2. /transcribe uses FastAPI UploadFile (multipart/form-data)
The contract specifies multipart/form-data for `/transcribe`. Use FastAPI's `UploadFile` + `Form` parameters. The existing `stt.transcribe()` function already accepts `bytes`, so it can be reused directly.

### 3. STT config check is a separate function
Add `is_stt_configured()` to `config.py` that checks `_config is not None and _config.stt is not None`. This cleanly separates the two 503 error cases: `NOT_CONFIGURED` (no LLM) vs `STT_NOT_CONFIGURED` (no STT).

### 4. is_configured() semantics change
`is_configured()` now means "LLM is configured" (the minimum for `/polish` with text input). A new `is_stt_configured()` covers STT specifically. This is a semantic narrowing but doesn't break existing callers since all current configs include both.

## Risks / Trade-offs

- **[Semantic change to is_configured()]** → Mitigated by the fact that config always had `llm` as required. No caller relies on `stt` being present via `is_configured()`.
- **[multipart vs JSON for /transcribe]** → The contract mandates multipart. This is different from `/polish` which uses JSON. Acceptable since `/transcribe` is a file upload endpoint.
