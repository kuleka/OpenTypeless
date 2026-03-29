# OpenTypeless Engine ↔ Client API Contract

> **Version**: 1.4.0-draft
> **Base URL**: `http://127.0.0.1:19823`
> **Port 可配置**: 通过环境变量 `OPEN_TYPELESS_PORT` 覆盖默认端口

本文档是 Engine 和所有 Client 之间的通信契约。Engine 和 Client 开发时必须遵守此文档定义的接口。任何接口变更需先更新本文档，再同步到两端代码。

---

## 目录

1. [连接约定](#1-连接约定)
2. [GET /health — 健康检查](#2-get-health--健康检查)
3. [POST /config — 配置 API Key 与偏好](#3-post-config--配置-api-key-与偏好)
4. [GET /config — 查看当前配置](#4-get-config--查看当前配置)
5. [POST /transcribe — 语音转文字](#5-post-transcribe--语音转文字)
6. [POST /polish — 核心润色管线](#6-post-polish--核心润色管线)
7. [GET /contexts — 获取场景配置](#7-get-contexts--获取场景配置)
8. [POST /contexts — 更新场景配置](#8-post-contexts--更新场景配置)
9. [错误码约定](#9-错误码约定)
10. [场景类型定义](#10-场景类型定义)
11. [Mock 响应示例](#11-mock-响应示例)

---

## 1. 连接约定

| 项目 | 值 |
|------|-----|
| 协议 | HTTP (本地通信，无需 HTTPS) |
| 地址 | `127.0.0.1` |
| 默认端口 | `19823` |
| Content-Type | `application/json` |
| 编码 | UTF-8 |

**Client 职责**：
- 启动时调用 `GET /health` 确认 Engine 在线
- 连接成功后调用 `POST /config` 将用户配置的 API Key 和偏好推送给 Engine
- 录音结束后，根据用户选择的 STT 模式：
  - **本地 STT 模式**：Client 本地转写后，将文字发送到 `POST /polish`
  - **远程 STT 模式**：将音频发送到 `POST /transcribe` 获取转写文字，再发送到 `POST /polish`；或直接将音频发送到 `POST /polish`（Engine 内部完成 STT + 润色）
- 收到响应后将 `text` 字段粘贴到光标位置

**Engine 职责**：
- 监听本地端口，接受 HTTP 请求
- `/transcribe`：音频解码 → STT 转写 → 返回原始文本
- `/polish`：接受文字或音频 → (可选 STT) → 场景检测 → Prompt 组装 → LLM 润色
- 返回结构化 JSON 响应

---

## 2. GET /health — 健康检查

Client 用此端点确认 Engine 是否在线。

### Request

```
GET /health
```

无请求体。

### Response — 200 OK

```json
{
  "status": "ok",
  "version": "0.1.0"
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `status` | string | 固定为 `"ok"` |
| `version` | string | Engine 的语义化版本号 |

---

## 3. POST /config — 配置 API Key 与偏好

Client 启动后应立即调用此端点，将用户在客户端 UI 中配置的 API 连接信息推送给 Engine。配置保存在 Engine 内存中，Engine 重启后需要重新配置。

**Engine 不从环境变量读取 API Key**，所有密钥和连接信息必须通过此端点由 Client 提供。

**Engine 是 provider-agnostic 的**：它不关心背后是 Groq、OpenAI 还是 Deepgram，只要目标 API 兼容 OpenAI 格式即可。具体的 provider 选择和 URL 映射是 Client 侧的 UX 逻辑。

### Request

```
POST /config
Content-Type: application/json
```

```json
{
  "stt": {
    "api_base": "https://api.groq.com/openai/v1",
    "api_key": "gsk_xxxxxxxxxxxx",
    "model": "whisper-large-v3"
  },
  "llm": {
    "api_base": "https://openrouter.ai/api/v1",
    "api_key": "sk-or-xxxxxxxxxxxx",
    "model": "minimax/minimax-m2.7"
  },
  "default_language": "auto"
}
```

#### 请求字段

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `stt` | object | 否 | `null` | STT 服务配置。本地 STT 模式下可不配置；调用 `/transcribe` 或带音频的 `/polish` 时必须已配置 |
| `stt.api_base` | string | 条件必填 | — | STT API 的 Base URL（须兼容 OpenAI Whisper 格式） |
| `stt.api_key` | string | 条件必填 | — | STT 服务的 API Key |
| `stt.model` | string | 条件必填 | — | STT 模型标识，如 `"whisper-large-v3"` |
| `llm` | object | **是** | — | LLM 服务配置 |
| `llm.api_base` | string | **是** | — | LLM API 的 Base URL（须兼容 OpenAI Chat Completions 格式） |
| `llm.api_key` | string | **是** | — | LLM 服务的 API Key |
| `llm.model` | string | **是** | — | LLM 模型标识，如 `"minimax/minimax-m2.7"` |
| `default_language` | string | 否 | `"auto"` | 默认语言（可被 `/polish` 请求覆盖） |

> **本地 STT 模式**：如果 Client 使用本地模型（如 WhisperKit）做转写，可以不配置 `stt`，只配置 `llm`。此时 Client 将转写好的文字直接发给 `/polish`。但如果尝试调用 `/transcribe` 或向 `/polish` 发送音频数据，Engine 会返回 `503 STT_NOT_CONFIGURED`。

#### 常见 Provider 配置示例

**Groq + OpenRouter**（推荐，性价比高）：
```json
{
  "stt": {
    "api_base": "https://api.groq.com/openai/v1",
    "api_key": "gsk_xxx",
    "model": "whisper-large-v3"
  },
  "llm": {
    "api_base": "https://openrouter.ai/api/v1",
    "api_key": "sk-or-xxx",
    "model": "minimax/minimax-m2.7"
  }
}
```

**OpenAI 全家桶**：
```json
{
  "stt": {
    "api_base": "https://api.openai.com/v1",
    "api_key": "sk-xxx",
    "model": "whisper-1"
  },
  "llm": {
    "api_base": "https://api.openai.com/v1",
    "api_key": "sk-xxx",
    "model": "gpt-4o-mini"
  }
}
```

**Deepgram STT + 本地 Ollama LLM**：
```json
{
  "stt": {
    "api_base": "https://api.deepgram.com/v1",
    "api_key": "dg_xxx",
    "model": "nova-2"
  },
  "llm": {
    "api_base": "http://localhost:11434/v1",
    "api_key": "ollama",
    "model": "llama3"
  }
}
```

### Response — 200 OK

```json
{
  "status": "configured"
}
```

### Response — 422

当必填字段缺失时：

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Missing required field: stt.api_key"
  }
}
```

---

## 4. GET /config — 查看当前配置

查看 Engine 当前的配置状态（API Key 脱敏显示）。

### Request

```
GET /config
```

### Response — 200 OK（已配置）

```json
{
  "configured": true,
  "stt": {
    "api_base": "https://api.groq.com/openai/v1",
    "api_key": "gsk_****xxxx",
    "model": "whisper-large-v3"
  },
  "llm": {
    "api_base": "https://openrouter.ai/api/v1",
    "api_key": "sk-or-****xxxx",
    "model": "minimax/minimax-m2.7"
  },
  "default_language": "auto"
}
```

### Response — 200 OK（未配置）

```json
{
  "configured": false,
  "stt": null,
  "llm": null,
  "default_language": "auto"
}
```

> API Key 脱敏规则：保留前缀（第一个 `_` 之前的部分）+ `****` + 最后 4 位，如 `gsk_****a1b2`、`sk-or-****c3d4`

---

## 5. POST /transcribe — 语音转文字

独立的 STT 端点。Client 发送音频，Engine 返回转写文本。适用于：
- Client 需要拿到原始转写结果（如展示给用户确认）
- 只需转写不需要润色的场景
- 调试时分别测试 STT 和 LLM

> **前置条件**：必须先通过 `POST /config` 配置 `stt`。未配置时返回 `503 STT_NOT_CONFIGURED`。

### Request

```http
POST /transcribe
Content-Type: multipart/form-data
```

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `file` | binary | **是** | — | 音频文件（WAV 或 M4A） |
| `language` | string | 否 | config 中的 `default_language` | 语言提示：`"auto"` / `"en"` / `"zh"` 等 |

#### 音频要求

- 格式：WAV (16kHz, mono, 16-bit PCM) 或 M4A
- 典型时长：5-30 秒
- 文件大小通常 < 500KB

### Response — 200 OK

```json
{
  "text": "hi tom thanks for the report i've reviewed the numbers and everything looks good",
  "language_detected": "en",
  "duration_ms": 5200,
  "stt_ms": 250
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `text` | string | STT 原始转写文本 |
| `language_detected` | string | 检测到的语言代码（如 `"en"`、`"zh"`） |
| `duration_ms` | integer | 音频时长（毫秒） |
| `stt_ms` | integer | STT 转写耗时（毫秒） |

### Response — 503

```json
{
  "error": {
    "code": "STT_NOT_CONFIGURED",
    "message": "STT is not configured. Call POST /config with stt settings first, or use local STT on the client."
  }
}
```

---

## 6. POST /polish — 核心润色管线

这是 Engine 的核心端点。Client 发送**文字或音频**和当前 app 上下文，Engine 返回润色后的文本。

支持两种输入模式：
- **文字输入**（本地 STT 模式）：Client 本地转写后，将 `text` 直接传入，Engine 跳过 STT 直接润色
- **音频输入**（远程 STT 模式）：Client 传入 `audio_base64`，Engine 内部完成 STT + 润色

> **前置条件**：必须先调用 `POST /config` 配置 LLM。如果传入音频，还需已配置 STT。

### Request

```http
POST /polish
Content-Type: application/json
```

```json
{
  "text": "hi tom thanks for the report i've reviewed the numbers",
  "context": {
    "app_id": "com.apple.mail",
    "window_title": "Compose New Message"
  },
  "options": {
    "task": "polish"
  }
}
```

或（音频输入模式）：

```json
{
  "audio_base64": "<base64 编码的音频数据>",
  "audio_format": "wav",
  "context": {
    "app_id": "com.apple.mail",
    "window_title": "Compose New Message"
  },
  "options": {
    "task": "polish",
    "language": "auto"
  }
}
```

#### 请求字段

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `text` | string | 二选一 | — | 已转写的文本（本地 STT 模式）。与 `audio_base64` 互斥，二者必传其一 |
| `audio_base64` | string | 二选一 | — | Base64 编码的音频数据（远程 STT 模式）。与 `text` 互斥 |
| `audio_format` | string | 否 | `"wav"` | 音频格式：`"wav"` 或 `"m4a"`。仅当传入 `audio_base64` 时有效 |
| `context` | object | 否 | `{}` | 当前 app 上下文，用于场景检测 |
| `context.app_id` | string | 否 | `""` | macOS bundle ID，如 `"com.apple.mail"` |
| `context.window_title` | string | 否 | `""` | 当前窗口标题 |
| `options` | object | 否 | `{}` | 可选配置，用于覆盖 `/config` 中的默认值 |
| `options.task` | string | 否 | `"polish"` | 任务类型：`"polish"`（润色）、`"translate"`（翻译）。详见下方 [Task 类型说明](#task-类型说明) |
| `options.language` | string | 否 | config 中的 `default_language` | STT 语言提示（仅音频模式有效）：`"auto"` / `"en"` / `"zh"` 等 |
| `options.model` | string | 否 | config 中的 `llm.model` | 覆盖本次请求使用的 LLM 模型 |
| `options.output_language` | string | 条件必填 | `null` | 输出语言。当 `task = "translate"` 时**必填**，如 `"en"`、`"zh"`、`"ja"`。其他 task 时忽略 |

#### 输入校验规则

- `text` 和 `audio_base64` 都不传 → **422 VALIDATION_ERROR**：`"Either text or audio_base64 must be provided"`
- `text` 和 `audio_base64` 同时传 → **422 VALIDATION_ERROR**：`"text and audio_base64 are mutually exclusive"`
- 传了 `audio_base64` 但 STT 未配置 → **503 STT_NOT_CONFIGURED**

#### Task 类型说明

| task | 说明 | output_language | Engine 行为 |
|------|------|----------------|------------|
| `"polish"` | 润色（默认） | 忽略 | 根据场景选择润色 prompt，输出与输入同语言 |
| `"translate"` | 翻译 | **必填** | 使用翻译 prompt，将文本翻译为 `output_language` 指定的语言 |

> **扩展说明**：未来如需增加新任务（如 `"summarize"`），只需在 Engine 的 prompt 模板中添加对应条目，并在此处更新文档。Client 只需传不同的 `task` 值。

#### Task 校验规则

- `task = "translate"` 但 `output_language` 为空 → Engine 返回 **422 VALIDATION_ERROR**：`"output_language is required when task is translate"`
- `task` 为不支持的值 → Engine 返回 **422 VALIDATION_ERROR**：`"Unsupported task: xxx. Supported: polish, translate"`

### Response — 200 OK

```json
{
  "text": "Hi Tom, thanks for the report. I've reviewed the numbers and everything looks good.",
  "raw_transcript": "hi tom thanks for the report i've reviewed the numbers and everything looks good",
  "task": "polish",
  "context_detected": "email",
  "model_used": "minimax/minimax-m2.7",
  "stt_ms": 250,
  "llm_ms": 180,
  "total_ms": 430
}
```

#### 响应字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `text` | string | 处理后的最终文本，Client 应将此文本粘贴到光标位置 |
| `raw_transcript` | string | STT 原始转写文本。文字输入模式下与输入的 `text` 相同 |
| `task` | string | 实际执行的任务类型：`"polish"` 或 `"translate"` |
| `context_detected` | string | 检测到的场景类型（见[场景类型定义](#10-场景类型定义)） |
| `model_used` | string | 实际使用的 LLM 模型标识 |
| `stt_ms` | integer | STT 转写耗时（毫秒）。文字输入模式下为 `0` |
| `llm_ms` | integer | LLM 处理耗时（毫秒） |
| `total_ms` | integer | 端到端总耗时（毫秒） |

---

## 7. GET /contexts — 获取场景配置

查看当前生效的所有场景匹配规则。

### Request

```
GET /contexts
```

### Response — 200 OK

```json
{
  "contexts": {
    "email": {
      "match_rules": {
        "app_ids": ["com.apple.mail", "com.microsoft.Outlook"],
        "window_title_contains": ["Gmail", "Outlook"]
      }
    },
    "chat": {
      "match_rules": {
        "app_ids": ["com.tinyspeck.slackmacgap", "com.tencent.xinWeChat"],
        "window_title_contains": ["Slack", "Discord", "Telegram"]
      }
    },
    "ai_chat": {
      "match_rules": {
        "app_ids": [],
        "window_title_contains": ["ChatGPT", "Claude", "Cursor"]
      }
    },
    "document": {
      "match_rules": {
        "app_ids": ["com.apple.Notes", "md.obsidian"],
        "window_title_contains": ["Notion", "Google Docs"]
      }
    },
    "code": {
      "match_rules": {
        "app_ids": ["com.microsoft.VSCode", "com.jetbrains.intellij"],
        "window_title_contains": ["Xcode"]
      }
    },
    "default": {
      "match_rules": {
        "app_ids": [],
        "window_title_contains": []
      }
    }
  }
}
```

---

## 8. POST /contexts — 更新场景配置

动态更新场景匹配规则（仅保存在内存中，重启后恢复默认）。

### Request

```
POST /contexts
Content-Type: application/json
```

```json
{
  "scene": "email",
  "match_rules": {
    "app_ids": ["com.apple.mail", "com.microsoft.Outlook", "com.sparkmailapp.Spark"],
    "window_title_contains": ["Gmail", "Outlook", "ProtonMail"]
  }
}
```

### Response — 200 OK

```json
{
  "status": "updated",
  "scene": "email"
}
```

---

## 9. 错误码约定

所有错误响应使用统一格式：

```json
{
  "error": {
    "code": "<ERROR_CODE>",
    "message": "Human-readable error description"
  }
}
```

| HTTP 状态码 | 错误码 | 触发条件 |
|-------------|--------|----------|
| **400** | `INVALID_AUDIO` | 音频数据无效（`audio_base64` 不是合法 Base64，或 `/transcribe` 的文件格式不支持） |
| **422** | `VALIDATION_ERROR` | 请求校验失败（如 `text` 和 `audio_base64` 都未传、同时传了两者、缺少必填字段等） |
| **503** | `NOT_CONFIGURED` | 尚未调用 `POST /config` 配置 LLM，Engine 无法处理润色请求 |
| **503** | `STT_NOT_CONFIGURED` | 请求需要 STT（`/transcribe` 或 `/polish` 带音频）但未配置 `stt` |
| **502** | `STT_FAILURE` | STT 服务请求失败或超时（30 秒） |
| **502** | `LLM_FAILURE` | LLM 服务请求失败或超时（30 秒） |
| **500** | `INTERNAL_ERROR` | Engine 内部未预期的错误 |

### 错误响应示例

```json
{
  "error": {
    "code": "STT_FAILURE",
    "message": "STT API request to https://api.groq.com/openai/v1 timed out after 30 seconds"
  }
}
```

---

## 10. 场景类型定义

Engine 支持 6 种场景，每种场景有不同的润色风格：

| 场景 | 说明 | 润色风格 |
|------|------|----------|
| `email` | 邮件应用 | 正式、结构化、专业语气 |
| `chat` | 即时通讯 | 口语化、简洁、轻松 |
| `ai_chat` | AI 对话工具 | 结构化的 prompt、清晰指令 |
| `document` | 文档/笔记 | 段落式、完整句子、书面语 |
| `code` | 代码编辑器 | 技术性、精确、简洁 |
| `default` | 未匹配时的兜底 | 自动检测语气 |

**匹配优先级**：按 email → chat → ai_chat → document → code → default 顺序，**第一个匹配的场景生效**。

**匹配逻辑**：
1. 先检查 `app_id` 是否精确匹配 `app_ids` 列表中的任一项
2. 再检查 `window_title` 是否包含 `window_title_contains` 列表中的任一子串
3. 两者任一命中即算匹配
4. 全部未匹配则使用 `default`

---

## 11. Mock 响应示例

**Client 开发时**可使用以下 mock 响应来模拟 Engine，无需等待 Engine 完成：

### Mock /health

```json
{
  "status": "ok",
  "version": "0.1.0-mock"
}
```

### Mock /config

请求：
```json
{
  "stt": {
    "api_base": "https://api.groq.com/openai/v1",
    "api_key": "gsk_test_key",
    "model": "whisper-large-v3"
  },
  "llm": {
    "api_base": "https://openrouter.ai/api/v1",
    "api_key": "sk-or-test_key",
    "model": "minimax/minimax-m2.7"
  }
}
```

Mock 响应：
```json
{
  "status": "configured"
}
```

### Mock /transcribe

请求（multipart/form-data，file 字段为音频文件）：

Mock 响应：

```json
{
  "text": "hi tom thanks for sending the report i've reviewed the numbers and everything looks good",
  "language_detected": "en",
  "duration_ms": 5200,
  "stt_ms": 0
}
```

### Mock /polish — 文字输入模式（本地 STT）

请求：

```json
{
  "text": "hi tom thanks for sending the report i've reviewed the numbers and everything looks good let me know if you need anything else",
  "context": {
    "app_id": "com.apple.mail",
    "window_title": "Compose"
  }
}
```

Mock 响应：

```json
{
  "text": "Hi Tom,\n\nThank you for sending the report. I've reviewed the numbers and everything looks good. Let me know if you need anything else.\n\nBest regards",
  "raw_transcript": "hi tom thanks for sending the report i've reviewed the numbers and everything looks good let me know if you need anything else",
  "task": "polish",
  "context_detected": "email",
  "model_used": "mock",
  "stt_ms": 0,
  "llm_ms": 0,
  "total_ms": 0
}
```

### Mock /polish — 音频输入模式（远程 STT）

请求：

```json
{
  "audio_base64": "UklGRiQAAABXQVZFZm10IBAAAA...",
  "audio_format": "wav",
  "context": {
    "app_id": "com.apple.mail",
    "window_title": "Compose"
  }
}
```

Mock 响应：

```json
{
  "text": "Hi Tom,\n\nThank you for sending the report. I've reviewed the numbers and everything looks good. Let me know if you need anything else.\n\nBest regards",
  "raw_transcript": "hi tom thanks for sending the report i've reviewed the numbers and everything looks good let me know if you need anything else",
  "task": "polish",
  "context_detected": "email",
  "model_used": "mock",
  "stt_ms": 250,
  "llm_ms": 180,
  "total_ms": 430
}
```

### Mock /polish — Chat 场景

请求：
```json
{
  "audio_base64": "UklGRiQAAABXQVZFZm10IBAAAA...",
  "audio_format": "wav",
  "context": {
    "app_id": "com.tinyspeck.slackmacgap",
    "window_title": "#general - Slack"
  }
}
```

Mock 响应：
```json
{
  "text": "sounds good, let's sync up after lunch 👍",
  "raw_transcript": "sounds good let's sync up after lunch",
  "task": "polish",
  "context_detected": "chat",
  "model_used": "mock",
  "stt_ms": 0,
  "llm_ms": 0,
  "total_ms": 0
}
```

### Mock /polish — 翻译场景（中文语音 → 英文输出）

请求：
```json
{
  "audio_base64": "UklGRiQAAABXQVZFZm10IBAAAA...",
  "audio_format": "wav",
  "context": {
    "app_id": "com.apple.mail",
    "window_title": "Compose"
  },
  "options": {
    "task": "translate",
    "output_language": "en"
  }
}
```

Mock 响应：
```json
{
  "text": "Hi Tom, the meeting is at 3 PM this afternoon. Please bring the quarterly report.",
  "raw_transcript": "汤姆你好今天下午三点开会请带上季度报告",
  "task": "translate",
  "context_detected": "email",
  "model_used": "mock",
  "stt_ms": 0,
  "llm_ms": 0,
  "total_ms": 0
}
```

### Mock /polish — 中文场景

请求：
```json
{
  "audio_base64": "UklGRiQAAABXQVZFZm10IBAAAA...",
  "audio_format": "wav",
  "context": {
    "app_id": "com.apple.Notes",
    "window_title": "Meeting Notes"
  },
  "options": {
    "language": "zh"
  }
}
```

Mock 响应：
```json
{
  "text": "今天下午三点开会讨论了项目进度，主要结论如下：\n\n1. 后端 API 已完成 80%\n2. 前端预计下周交付\n3. 需要补充单元测试",
  "raw_transcript": "今天下午三点开会讨论了项目进度主要结论如下后端API已完成百分之八十前端预计下周交付需要补充单元测试",
  "task": "polish",
  "context_detected": "document",
  "model_used": "mock",
  "stt_ms": 0,
  "llm_ms": 0,
  "total_ms": 0
}
```

---

## 附录：Client 集成清单

Client 端需要实现以下模块来对接 Engine：

| 模块 | 职责 | 对应 Pindrop 现有文件 |
|------|------|----------------------|
| **EngineClient** | HTTP 客户端，调用 `/health`、`/config`、`/transcribe`、`/polish` | 新建 |
| **ActiveAppDetector** | 获取当前 app 的 bundle ID 和 window title | 已有 `ContextEngineService.swift`，可复用 |
| **AudioEncoder** | 将录音数据 Base64 编码（远程 STT 模式） | 新建（简单工具类） |
| **TranscriptionService 改造** | 支持双模式：本地 WhisperKit 或远程 Engine `/transcribe` | 改造 `TranscriptionService.swift`，保留本地引擎 |
| **PolishService** | 调用 Engine `/polish` 做润色（替代原有的直接调 Claude API） | 新建（替代 `AIEnhancementService.swift`） |
| **OutputManager** | 将润色文本粘贴到光标位置 | 已有，无需改动 |
| **录音模块** | 录音并输出 WAV/M4A 数据 | 已有 `AudioRecorder.swift`，无需改动 |
| **设置 UI** | STT 模式选择（本地/远程）、provider 配置 | 改造 `AIEnhancementSettingsView.swift` 等 |

---

## 变更日志

| 日期 | 版本 | 变更内容 |
|------|------|----------|
| 2026-03-28 | 1.0.0-draft | 初始版本，基于 OpenSpec Phase 1 规格创建 |
| 2026-03-28 | 1.1.0-draft | 新增 `POST /config` 和 `GET /config` 端点；API Key 由 Client 通过 `/config` 提供，不再使用环境变量；新增 `503 NOT_CONFIGURED` 错误码 |
| 2026-03-28 | 1.2.0-draft | Config 改为 provider-agnostic 的 `stt` / `llm` 分组结构；Engine 不绑定任何特定 provider，只要求目标 API 兼容 OpenAI 格式；支持本地模型（如 Ollama） |
| 2026-03-28 | 1.3.0-draft | `/polish` 新增 `options.task`（`polish` / `translate`）和 `options.output_language` 参数；响应新增 `task` 字段；translate 时 output_language 为必填，校验失败返回 422 |
| 2026-03-29 | 1.4.0-draft | 新增 `POST /transcribe` 端点（multipart/form-data）；`/polish` 支持 `text` 或 `audio_base64` 二选一输入；`POST /config` 中 `stt` 改为可选（本地 STT 模式不需要配置远程 STT）；新增 `503 STT_NOT_CONFIGURED` 错误码；更新 Client 集成清单 |
