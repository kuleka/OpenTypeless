# OpenTypeless Engine ↔ Client API Contract

> **Version**: 1.0.0-draft
> **Base URL**: `http://127.0.0.1:19823`
> **Port 可配置**: 通过环境变量 `OPEN_TYPELESS_PORT` 覆盖默认端口

本文档是 Engine 和所有 Client 之间的通信契约。Engine 和 Client 开发时必须遵守此文档定义的接口。任何接口变更需先更新本文档，再同步到两端代码。

---

## 目录

1. [连接约定](#1-连接约定)
2. [GET /health — 健康检查](#2-get-health--健康检查)
3. [POST /config — 配置 API Key 与偏好](#3-post-config--配置-api-key-与偏好)
4. [GET /config — 查看当前配置](#4-get-config--查看当前配置)
5. [POST /polish — 核心润色管线](#5-post-polish--核心润色管线)
6. [GET /contexts — 获取场景配置](#6-get-contexts--获取场景配置)
7. [POST /contexts — 更新场景配置](#7-post-contexts--更新场景配置)
8. [错误码约定](#8-错误码约定)
9. [场景类型定义](#9-场景类型定义)
10. [Mock 响应示例](#10-mock-响应示例)

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
- 录音结束后将音频 base64 编码，连同 app 上下文一起发送到 `POST /polish`
- 收到响应后将 `text` 字段粘贴到光标位置

**Engine 职责**：
- 监听本地端口，接受 HTTP 请求
- 管线执行：音频解码 → STT 转写 → 场景检测 → Prompt 组装 → LLM 润色
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

Client 启动后应立即调用此端点，将用户在客户端 UI 中配置的 API Key 和偏好推送给 Engine。配置保存在 Engine 内存中，Engine 重启后需要重新配置。

**Engine 不从环境变量读取 API Key**，所有密钥必须通过此端点由 Client 提供。

### Request

```
POST /config
Content-Type: application/json
```

```json
{
  "groq_api_key": "gsk_xxxxxxxxxxxx",
  "openrouter_api_key": "sk-or-xxxxxxxxxxxx",
  "default_model": "minimax/minimax-m2.7",
  "default_language": "auto"
}
```

#### 请求字段

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `groq_api_key` | string | **是** | — | Groq API Key，用于 STT 转写 |
| `openrouter_api_key` | string | **是** | — | OpenRouter API Key，用于 LLM 润色 |
| `default_model` | string | 否 | `"minimax/minimax-m2.7"` | 默认 LLM 模型（可被 `/polish` 请求覆盖） |
| `default_language` | string | 否 | `"auto"` | 默认语言（可被 `/polish` 请求覆盖） |

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
    "message": "Missing required field: groq_api_key"
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
  "groq_api_key": "gsk_****xxxx",
  "openrouter_api_key": "sk-or-****xxxx",
  "default_model": "minimax/minimax-m2.7",
  "default_language": "auto"
}
```

### Response — 200 OK（未配置）

```json
{
  "configured": false,
  "groq_api_key": null,
  "openrouter_api_key": null,
  "default_model": "minimax/minimax-m2.7",
  "default_language": "auto"
}
```

> API Key 脱敏规则：仅显示前缀 + 最后 4 位，如 `gsk_****a1b2`

---

## 5. POST /polish — 核心润色管线

这是 Engine 的核心端点。Client 发送录音音频和当前 app 上下文，Engine 返回润色后的文本。

> **前置条件**：必须先调用 `POST /config` 配置 API Key。未配置时调用此端点会返回 `503 NOT_CONFIGURED`。

### Request

```
POST /polish
Content-Type: application/json
```

```json
{
  "audio_base64": "<base64 编码的音频数据>",
  "audio_format": "wav",
  "context": {
    "app_id": "com.apple.mail",
    "window_title": "Compose New Message"
  },
  "options": {
    "language": "auto",
    "model": "minimax/minimax-m2.7"
  }
}
```

#### 请求字段

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `audio_base64` | string | **是** | — | Base64 编码的音频数据 |
| `audio_format` | string | 否 | `"wav"` | 音频格式：`"wav"` 或 `"m4a"` |
| `context` | object | 否 | `{}` | 当前 app 上下文，用于场景检测 |
| `context.app_id` | string | 否 | `""` | macOS bundle ID，如 `"com.apple.mail"` |
| `context.window_title` | string | 否 | `""` | 当前窗口标题 |
| `options` | object | 否 | `{}` | 可选配置 |
| `options.language` | string | 否 | `"auto"` | 语言提示：`"auto"` / `"en"` / `"zh"` 等 |
| `options.model` | string | 否 | `"minimax/minimax-m2.7"` | OpenRouter 模型标识 |

#### 音频要求

- 格式：WAV (16kHz, mono, 16-bit PCM) 或 M4A
- 典型时长：5-30 秒
- Base64 编码后大小通常 < 500KB

### Response — 200 OK

```json
{
  "text": "Hi Tom, thanks for the report. I've reviewed the numbers and everything looks good.",
  "raw_transcript": "hi tom thanks for the report i've reviewed the numbers and everything looks good",
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
| `text` | string | 润色后的最终文本，Client 应将此文本粘贴到光标位置 |
| `raw_transcript` | string | STT 原始转写文本（未润色） |
| `context_detected` | string | 检测到的场景类型（见[场景类型定义](#7-场景类型定义)） |
| `model_used` | string | 实际使用的 LLM 模型标识 |
| `stt_ms` | integer | STT 转写耗时（毫秒） |
| `llm_ms` | integer | LLM 润色耗时（毫秒） |
| `total_ms` | integer | 端到端总耗时（毫秒） |

---

## 6. GET /contexts — 获取场景配置

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

## 7. POST /contexts — 更新场景配置

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

## 8. 错误码约定

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
| **400** | `INVALID_AUDIO` | `audio_base64` 不是合法的 Base64 数据 |
| **422** | `VALIDATION_ERROR` | 缺少必填字段（如 `audio_base64`）或字段类型错误 |
| **503** | `NOT_CONFIGURED` | 尚未调用 `POST /config` 配置 API Key，Engine 无法处理请求 |
| **502** | `STT_FAILURE` | STT 服务（Groq）请求失败或超时 |
| **502** | `LLM_FAILURE` | LLM 服务（OpenRouter）请求失败或超时 |
| **500** | `INTERNAL_ERROR` | Engine 内部未预期的错误 |

### 错误响应示例

```json
{
  "error": {
    "code": "STT_FAILURE",
    "message": "Groq API request timed out after 30 seconds"
  }
}
```

---

## 9. 场景类型定义

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

## 10. Mock 响应示例

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
  "groq_api_key": "gsk_test_key",
  "openrouter_api_key": "sk-or-test_key"
}
```

Mock 响应：
```json
{
  "status": "configured"
}
```

### Mock /polish — Email 场景

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
  "context_detected": "email",
  "model_used": "mock",
  "stt_ms": 0,
  "llm_ms": 0,
  "total_ms": 0
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
  "context_detected": "chat",
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
| **EngineClient** | HTTP 客户端，调用 `/health`、`/config`、`/polish` | 新建 |
| **ActiveAppDetector** | 获取当前 app 的 bundle ID 和 window title | 新建（基于 Accessibility API） |
| **AudioEncoder** | 将录音数据 Base64 编码 | 新建（简单工具类） |
| **TranscriptionService 改造** | 把 WhisperKit 本地调用替换为 EngineClient 远程调用 | 改造 `TranscriptionService.swift` |
| **OutputManager** | 将润色文本粘贴到光标位置 | 已有，无需改动 |
| **录音模块** | 录音并输出 WAV/M4A 数据 | 已有 `AudioRecorder.swift`，可能需小幅适配 |

---

## 变更日志

| 日期 | 版本 | 变更内容 |
|------|------|----------|
| 2026-03-28 | 1.0.0-draft | 初始版本，基于 OpenSpec Phase 1 规格创建 |
| 2026-03-28 | 1.1.0-draft | 新增 `POST /config` 和 `GET /config` 端点；API Key 由 Client 通过 `/config` 提供，不再使用环境变量；新增 `503 NOT_CONFIGURED` 错误码 |
