# OpenTypeless

An open-source AI voice dictation tool. Speak naturally, get polished text at your cursor.

OpenTypeless removes filler words, fixes grammar, and adapts tone based on whether you're drafting an email or dictating in a general app context.

## Current State

OpenTypeless is currently being built as:

- a Python Engine that exposes localhost HTTP APIs
- a macOS client based on the Pindrop codebase

The macOS client Phase 1 integration is complete. The current implementation includes:

- `EngineClient` for `/health`, `/config`, `/transcribe`, `/polish`
- dual-mode transcription plumbing: local STT or remote Engine STT
- `PolishService` for Engine-based text polishing
- `AppCoordinator` wiring for the main dictation flow
- Engine settings UI and config sync
- app-level tests plus UI smoke coverage

The legacy quick-capture and AI-only auxiliary flows have been removed. The supported baseline now runs through the `Client + Engine` split.

Useful references:

- [Engine ↔ Client API contract](docs/api-contract.md)
- [macOS client Phase 1 summary](docs/macos-client-phase1.md)
- [macOS client README](clients/macos/README.md)
- [Current OpenSpec specs](openspec/specs)
- [Archived Phase 1 change](openspec/changes/archive/2026-03-30-phase1-macos-client)

## How It Works

```
🎙️ Voice Input
  -> local STT in macOS client OR remote Engine /transcribe
  -> Engine /polish
  -> 📋 Paste at Cursor
```

1. **Record** — Hold a hotkey to speak
2. **Transcribe** — Audio is transcribed either locally on macOS or remotely through Engine
3. **Polish** — Raw transcript is refined by Engine with scene-aware prompts
4. **Paste** — Polished text appears at your cursor position

## Scene-Aware Polishing

OpenTypeless detects which app you're using and adjusts its output:

| Scene | Apps | Style |
|-------|------|-------|
| Email | Mail, Outlook, Gmail, ProtonMail | Formal, structured email formatting |
| Default | Everything else | General cleanup while preserving meaning and tone |

## Architecture

```
┌─────────────────────┐       HTTP        ┌──────────────────┐
│ macOS Client (Swift)│ ◄──────────────► │ Python Engine     │
│ recording / hotkeys │   localhost:19823│ STT + polish APIs │
└─────────────────────┘                  └──────────────────┘
```

- **Engine**: owns HTTP endpoints and external provider integration
- **macOS Client**: owns recording, hotkeys, context capture, and output
- **Boundary**: defined by [`docs/api-contract.md`](docs/api-contract.md)

## Status

🚧 **Under active development**

- [x] Phase 1: macOS client and Engine integration foundation
- [x] Legacy client cleanup for retired quick capture and AI-only flows
- [ ] Broader UX polish and release hardening

## License

[MIT](LICENSE)

macOS client is based on [Pindrop](https://github.com/watzon/pindrop) by [@watzon](https://github.com/watzon), also MIT licensed.
