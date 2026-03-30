## Why

The macOS client (phase1-macos-client) has been merged to main, bringing API contract v1.4.0 which introduces dual-mode input for `/polish` (text or audio), a standalone `/transcribe` endpoint, and optional STT configuration. The engine code was built against v1.3.0 and no longer matches the contract that the client expects.

## What Changes

- **BREAKING**: `POST /config` — `stt` field becomes optional (was required). Client using local STT (e.g. WhisperKit) only needs to configure `llm`.
- **New endpoint**: `POST /transcribe` — standalone STT endpoint accepting multipart/form-data audio file, returns transcription with language detection and timing.
- **BREAKING**: `POST /polish` — now accepts either `text` (pre-transcribed) or `audio_base64` (remote STT), mutually exclusive. Previously `audio_base64` was always required.
- **New error code**: `STT_NOT_CONFIGURED` (503) — returned when STT is needed but not configured, separate from the existing `NOT_CONFIGURED`.

## Capabilities

### New Capabilities
- `transcribe-endpoint`: Standalone `POST /transcribe` endpoint with multipart file upload and transcription response

### Modified Capabilities
- `dual-mode-transcription`: `/polish` must accept `text` OR `audio_base64` input, with mutual exclusion validation
- `engine-polish`: Polish endpoint input model changes to support text-only mode (skip STT)

## Impact

- `engine/open_typeless/models.py` — ConfigRequest.stt becomes Optional, new TranscribeResponse model, PolishRequest gains `text` field
- `engine/open_typeless/config.py` — new `is_stt_configured()` helper, `get_masked_config()` handles None stt
- `engine/open_typeless/stt.py` — check stt config specifically (not just global config)
- `engine/open_typeless/server.py` — new `/transcribe` route, `/polish` dual-mode logic, new error code
- `engine/tests/` — all server and config tests need updating for new behavior
