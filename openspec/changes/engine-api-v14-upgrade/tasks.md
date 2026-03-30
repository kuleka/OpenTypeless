## 1. Models Update

- [ ] 1.1 Make `ConfigRequest.stt` optional (`Optional[STTConfig] = None`)
- [ ] 1.2 Make `PolishRequest.audio_base64` optional, add `text: Optional[str] = None`
- [ ] 1.3 Add `TranscribeResponse` model with `text`, `language_detected`, `duration_ms`, `stt_ms`

## 2. Configuration Management

- [ ] 2.1 Add `is_stt_configured()` function to `config.py`
- [ ] 2.2 Update `get_masked_config()` to handle `stt=None`
- [ ] 2.3 Update `test_config.py` — test LLM-only config, `is_stt_configured()`, masked config with no STT

## 3. STT Integration

- [ ] 3.1 Update `stt.transcribe()` to check `config.stt` specifically (not just global config)
- [ ] 3.2 Update `test_stt.py` — test STT-not-configured when config exists but stt is None

## 4. Server: /transcribe Endpoint

- [ ] 4.1 Implement `POST /transcribe` with `UploadFile` + optional `language` form field
- [ ] 4.2 Return `TranscribeResponse` on success, 503 `STT_NOT_CONFIGURED` when stt not set
- [ ] 4.3 Write tests for `/transcribe` — success, STT not configured, STT failure

## 5. Server: /polish Dual-Mode

- [ ] 5.1 Update `/polish` to accept `text` or `audio_base64` (mutually exclusive)
- [ ] 5.2 Add validation: neither provided → 422, both provided → 422, audio without STT → 503 `STT_NOT_CONFIGURED`
- [ ] 5.3 Text-mode path: skip STT, use `text` as `raw_transcript`, set `stt_ms=0`
- [ ] 5.4 Update `POST /config` to accept stt-optional config
- [ ] 5.5 Write tests for `/polish` text mode — success, no STT needed, correct `stt_ms=0`
- [ ] 5.6 Write tests for `/polish` validation — neither input, both inputs, audio without STT config

## 6. Verification

- [ ] 6.1 Run full test suite — all tests pass
- [ ] 6.2 Verify existing audio-mode tests still pass (backward compatibility)
