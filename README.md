# OpenTypeless

An open-source AI voice dictation tool. Speak naturally, get polished text at your cursor.

OpenTypeless removes filler words, fixes grammar, and adapts tone based on what app you're using (email, chat, code editor, etc.).

## Current State

OpenTypeless is currently being built as:

- a Python Engine that exposes localhost HTTP APIs
- a macOS client based on the Pindrop codebase

The macOS migration is in progress. The current Phase 1 implementation already includes:

- `EngineClient` for `/health`, `/config`, `/transcribe`, `/polish`
- dual-mode transcription plumbing: local STT or remote Engine STT
- `PolishService` for Engine-based text polishing

The full app pipeline and settings UI are still being wired in.

Useful references:

- [Engine ↔ Client API contract](docs/api-contract.md)
- [macOS client Phase 1 status](docs/macos-client-phase1.md)
- [macOS client README](clients/macos/README.md)

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
| Email | Mail, Outlook, Gmail | Formal, structured |
| Chat | Slack, WeChat, Discord, Telegram | Casual, concise |
| AI Chat | ChatGPT, Claude, Cursor | Structured prompts |
| Document | Notes, Notion, Obsidian, Word | Paragraph format |
| Code | VS Code, IntelliJ, Xcode | Technical, precise |
| Default | Everything else | Auto-detect |

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

- [ ] Phase 1: Core Engine and client integration end-to-end
- [ ] Phase 2: macOS settings and startup wiring
- [ ] Phase 3: enhancements and broader UX polish

## License

[MIT](LICENSE)

macOS client is based on [Pindrop](https://github.com/watzon/pindrop) by [@watzon](https://github.com/watzon), also MIT licensed.
