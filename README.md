# OpenTypeless

An open-source AI voice dictation tool. Speak naturally, get polished text at your cursor.

OpenTypeless removes filler words, fixes grammar, and adapts tone based on what app you're using (email, chat, code editor, etc.).

## How It Works

```
🎙️ Voice Input → ☁️ Cloud STT (Groq Whisper) → 🤖 LLM Polish (OpenRouter) → 📋 Paste at Cursor
```

1. **Record** — Hold a hotkey to speak
2. **Transcribe** — Audio is sent to Groq Whisper for fast speech-to-text (~200ms)
3. **Polish** — Raw transcript is refined by an LLM with scene-aware prompts
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
┌─────────────┐       HTTP        ┌──────────────────┐
│  macOS App   │ ◄──────────────► │   Python Engine   │
│  (Swift)     │   localhost:19823│   (FastAPI)        │
└─────────────┘                   └──────────────────┘
                                    │           │
                                    ▼           ▼
                               Groq Whisper  OpenRouter
                                 (STT)        (LLM)
```

- **Engine** (Python): HTTP server handling STT + LLM pipeline. Cross-platform.
- **macOS Client** (Swift): Native app based on [Pindrop](https://github.com/watzon/pindrop). Handles recording, hotkeys, and paste.

## Status

🚧 **Under active development**

- [ ] Phase 1: Core Engine (Python HTTP server + STT + LLM + prompt routing)
- [ ] Phase 2: macOS Client (Pindrop integration)
- [ ] Phase 3: Enhancements (style memory, streaming audio, input context)

## License

[MIT](LICENSE)

macOS client is based on [Pindrop](https://github.com/watzon/pindrop) by [@watzon](https://github.com/watzon), also MIT licensed.
