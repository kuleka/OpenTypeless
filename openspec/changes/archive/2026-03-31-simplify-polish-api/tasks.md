## 1. Engine Model

- [x] 1.1 Update `PolishRequest` in `models.py` — remove `audio_base64` and `audio_format` fields, make `text` required (`str` instead of `Optional[str]`)

## 2. Engine Server

- [x] 2.1 Remove audio branch from `/polish` route in `server.py` — remove base64 decode, STT call, mutual-exclusion validation; simplify to only accept `text`
- [x] 2.2 Remove `stt_ms` from `/polish` response (both success path and timing calculation)

## 3. Engine Tests

- [x] 3.1 Remove audio_base64 related tests from `test_server.py` (audio happy path, invalid base64, mutual exclusion, missing input)
- [x] 3.2 Update remaining `/polish` tests to use `text` as required field (no longer Optional)
- [x] 3.3 Run `pytest` — verify all tests pass

## 4. Documentation

- [x] 4.1 Update `docs/api-contract.md` — remove audio_base64/audio_format from `/polish` request, remove stt_ms from response, update field descriptions

## 5. Verification

- [x] 5.1 Run E2E tests to confirm `/polish` text-only flow still works end-to-end
