# Open Typeless — 项目规划文档

> 一个开源的 Typeless 平替方案。用云端 STT + LLM 润色，以不到 $1/月的成本实现 $30/月的商业产品体验。

---

## 1. 项目背景与动机

### 1.1 什么是 Typeless

Typeless 是一款 AI 语音听写工具（$12/月年付，$30/月月付）。核心功能是：用户自然说话 → 自动去除口头禅和重复 → 根据当前使用的应用自动调整语气 → 输出润色后的文字，直接粘贴到光标位置。

### 1.2 为什么做 Open Typeless

Typeless 的技术本质是两个 API 调用的组合：语音转文字（STT）+ 大语言模型润色（LLM）。这两个环节都有成熟的开源方案和廉价 API。我们通过自研，可以把月成本从 $12-30 降到 $0.1-3。

### 1.3 项目目标

- 开源、免费、跨平台（引擎层）
- macOS 原生客户端（首个前端实现）

---

## 2. 技术决策记录

以下是在项目规划阶段经过讨论确定的所有技术决策。

### 2.1 架构：Monorepo + 前后端分离

**决策**：核心引擎和客户端在同一个 Git 仓库（monorepo）中，但作为独立模块通过 HTTP 协议通信。

**理由**：
- 引擎必须跨平台可用（macOS/Windows/Linux 的不同客户端都能接入）
- 未来可能用不同语言重写引擎或客户端，HTTP 是最通用的通信协议
- Monorepo 方便管理、发版、社区贡献
- 本地 HTTP 通信延迟 <1ms，不影响用户体感

**否决的方案**：
- 引擎嵌入客户端进程（Swift 内直接调用）→ 否决原因：失去跨平台能力，未来换语言要重写
- 两个独立仓库 → 否决原因：增加管理成本，贡献者体验差
- stdin/stdout 管道通信 → 否决原因：进程管理复杂，不同操作系统行为差异大
- Unix socket → 否决原因：Windows 不原生支持

### 2.2 引擎语言：Python

**决策**：核心引擎用 Python 编写。

**理由**：
- 引擎的核心工作是调用云端 API（STT + LLM），不需要高性能计算
- Python 的 LLM 生态最丰富（OpenAI SDK、httpx、各种 STT 客户端库）
- 社区贡献者门槛最低
- 容易分发：`pip install open-typeless`

**否决的方案**：
- Rust → 否决原因：引擎没有性能瓶颈，Rust 的优势发挥不出来，增加贡献门槛
- Go → 否决原因：类似理由，LLM 生态不如 Python
- Swift → 否决原因：不跨平台

### 2.3 macOS 客户端基座：Pindrop

**决策**：macOS 客户端基于 Pindrop 项目改造。

**理由**：
- MIT 协议，无法律限制
- 纯 Swift/SwiftUI 原生实现，打包小（几十 MB vs Electron 几百 MB）
- 已解决全局快捷键、麦克风录音、自动粘贴、权限管理等底层问题
- 代码量小（164 commits），架构清晰，容易理解和改造
- 留出的空白（无场景检测、无 LLM 集成）正好是我们的独立贡献空间

**否决的方案**：
- VoiceInk → 否决原因：GPLv3 协议（fork 必须开源且使用相同协议），不接受 PR，代码量大（1055 commits）不容易理解
- OpenWhispr → 否决原因：Electron 架构，打包太重
- 从头写 → 否决原因：全局快捷键、权限管理等底层工作耗时且对简历无贡献
- SwiftShip 等 boilerplate → 否决原因：只解决项目初始化问题，不解决录音/快捷键/粘贴等领域特定问题

### 2.4 STT 方案：云端 API

**决策**：使用云端 STT API（首选 Groq Whisper，备选 Deepgram）。

**理由**：
- Groq Whisper 对 10 秒音频的处理延迟约 200-300ms，速度极快
- 支持中英混杂及 100+ 语言
- 不依赖本地 GPU，降低用户硬件门槛
- 成本极低：约 $0.004/分钟，日均 30 分钟听写约 $3.6/月

**延迟优化**：采用"边录边传"策略——用户说话时就通过 WebSocket 把音频流实时发给 STT，松开按键时 STT 已经处理了大部分音频，尾部处理仅需 50-100ms。

### 2.5 LLM 方案：OpenRouter + MiniMax M2.7

**决策**：通过 OpenRouter API 调用 MiniMax M2.7 做文本润色。

**理由**：
- MiniMax M2.7 价格 $0.30/百万输入 token，$1.20/百万输出 token
- OpenRouter 上还有 MiniMax M2.5 免费版（$0/百万 token）
- 日均 30 分钟听写产出约 6000 input token + 5000 output token/天，月成本约 $0.06
- OpenRouter 统一了 300+ 模型的 API 接口，用户可以自由切换模型

### 2.6 场景检测方案

**决策**：客户端通过 macOS Accessibility API 检测当前前台应用的 bundle ID 和窗口标题，将场景信息发送给引擎，引擎根据场景选择对应的 prompt 模板。

**技术实现**：
- macOS: `NSWorkspace.shared.frontmostApplication?.bundleIdentifier`
- 浏览器内页面判断：通过窗口标题（如 "Gmail" / "ChatGPT"）
- 场景映射表：app bundle ID → 场景枚举（email / chat / ai_chat / document / code / default）

**注意**：Typeless 的场景检测功能目前也是基于固定规则，不支持用户自定义（用户在 Product Hunt 上反馈过这个需求）。我们可以做得更灵活，支持用户自定义规则。

### 2.7 输出方式

**决策**：LLM 润色完成后，将完整结果一次性通过剪贴板粘贴到光标位置。

**否决的方案**：
- LLM 流式输出逐字粘贴 → 否决原因：剪贴板粘贴是一次性操作，无法逐字执行。用户体验也不合适——听写场景需要完整结果一次性出现。

### 2.8 SDD 工具：OpenSpec

**决策**：使用 OpenSpec 管理规格驱动开发流程。

**理由**：
- 轻量级：生成约 250 行 spec（vs Spec Kit 的 800 行）
- 适合 brownfield 开发（在已有项目上加功能）
- 支持 Claude Code、Cursor 等 20+ AI 工具
- 安装简单：`npm install -g @fission-ai/openspec`

**否决的方案**：
- GitHub Spec Kit → 否决原因：偏重型，适合大型 greenfield 项目，对我们这个体量的项目开销过大
- BMAD-METHOD → 否决原因：企业级框架，21 个 agent 的复杂度不适合个人项目

### 2.9 AI IDE：Claude Code

**决策**：主力开发工具使用 Claude Code（终端模式）。

**理由**：
- 与 OpenSpec 原生集成最好
- 对 Swift 和 Python 代码理解能力强
- 终端模式适合同时操作多个子目录（engine / clients/macos）

---

## 3. 仓库结构

```
open-typeless/
├── README.md
├── LICENSE (MIT)
│
├── engine/                           # 核心引擎（Python）
│   ├── pyproject.toml
│   ├── open_typeless/
│   │   ├── __init__.py
│   │   ├── server.py                 # 本地 HTTP server（localhost:19823）
│   │   ├── stt.py                    # 云端 STT 调用（Groq/Deepgram）
│   │   ├── llm.py                    # OpenRouter API 调用
│   │   ├── prompt_router.py          # 场景 → prompt 模板路由
│   │   ├── context.py                # 上下文组装（system + context + user text）
│   │   ├── style_memory.py           # 风格记忆系统（未来 Level 2）
│   │   └── prompts/
│   │       └── defaults.yaml         # 默认场景 prompt 配置
│   ├── cli.py                        # CLI 入口
│   └── tests/
│
├── clients/
│   ├── macos/                        # macOS 客户端（Swift，基于 Pindrop）
│   │   ├── OpenTypeless.xcodeproj
│   │   ├── App/
│   │   │   ├── Views/
│   │   │   ├── Services/
│   │   │   │   ├── AudioRecorder.swift      # Pindrop 已有
│   │   │   │   ├── HotkeyManager.swift      # Pindrop 已有
│   │   │   │   ├── OutputManager.swift      # Pindrop 已有
│   │   │   │   ├── ActiveAppDetector.swift  # 新增：场景检测
│   │   │   │   └── EngineClient.swift       # 新增：与引擎 HTTP 通信
│   │   │   └── Settings/
│   │   ├── LICENSE                          # 保留 Pindrop 的 MIT LICENSE
│   │   └── README.md                        # 注明 Based on Pindrop
│   │
│   ├── windows/                      # 未来扩展
│   │   └── README.md                 # "Coming soon / Contributors welcome"
│   │
│   └── linux/                        # 未来扩展
│       └── README.md
│
├── docs/
│   ├── architecture.md               # 架构说明
│   ├── engine-api.md                 # 引擎 HTTP API 文档
│   └── contributing.md               # 贡献指南
│
└── openspec/                         # OpenSpec SDD 文档
    ├── project.md
    ├── specs/
    └── changes/
```

---

## 4. 引擎 HTTP API 协议

引擎作为本地 HTTP server 运行在 `localhost:19823`。

### 4.1 POST /polish

主接口：接收音频 + 场景信息，返回润色后的文本。

**请求：**
```json
{
  "audio_base64": "UklGRi...",
  "audio_format": "wav",
  "context": {
    "app_id": "com.apple.mail",
    "app_name": "Mail",
    "window_title": "Re: Q3 Report"
  },
  "options": {
    "model": "minimax/minimax-m2.7",
    "language": "auto"
  }
}
```

**响应：**
```json
{
  "text": "Hi Tom,\n\nThanks for sharing the Q3 report...",
  "raw_transcript": "嗯 那个 hi tom 就是 thanks for sharing the 那个 Q3 report",
  "context_detected": "email",
  "model_used": "minimax/minimax-m2.7",
  "stt_ms": 210,
  "llm_ms": 185,
  "total_ms": 395
}
```

### 4.2 GET /health

健康检查。客户端启动时调用，确认引擎已运行。

**响应：**
```json
{
  "status": "ok",
  "version": "0.1.0"
}
```

### 4.3 GET /contexts

获取当前支持的场景列表和对应的 prompt 模板。

### 4.4 POST /contexts

用户自定义场景规则和 prompt 模板。

---

## 5. Prompt 架构设计

### 5.1 三层 Prompt 结构

每次调用 LLM，发送的 prompt 由三部分组装：

```
┌──────────────────────────────────────┐
│  System Prompt（固定，所有场景共享）     │
│  定义基本行为：去语气词、保留意图、格式化   │
├──────────────────────────────────────┤
│  Context Prompt（动态，根据场景切换）     │
│  根据检测到的 app 选择对应场景模板        │
├──────────────────────────────────────┤
│  User Message（STT 原始转录文本）        │
└──────────────────────────────────────┘
```

### 5.2 System Prompt 设计

```
你是一个语音转文字润色助手。用户会给你一段语音转录的原始文本。
你的任务：
1. 删除所有口头禅和语气词（嗯、啊、那个、就是说、然后、basically、you know、like...）
2. 如果用户中途改口或重复，只保留最终意图
3. 修正明显的语音识别错误
4. 当用户明显在列举事项时（使用"第一、第二"、"首先、其次"、"一个是...另一个是..."等表述），自动转为编号列表
5. 当用户说"包括"、"有以下几点"、"分别是"等词时，后续内容用列表格式呈现
6. 不要改变用户的原始意思，不要添加用户没说的内容
7. 直接输出润色后的文本，不要加任何解释或前缀
```

### 5.3 场景 Prompt 模板

```yaml
# defaults.yaml

email:
  match_rules:
    - app_id: "com.apple.mail"
    - app_id: "com.microsoft.Outlook"
    - window_title_contains: "Gmail"
  prompt: |
    额外规则：
    - 自动生成邮件格式：Subject / 称呼 / 正文 / 结尾
    - 语气正式、专业
    - 如果用户提到收件人名字，放在称呼里

chat:
  match_rules:
    - app_id: "com.tencent.xinWeChat"
    - app_id: "com.tinyspeck.slackmacgap"
    - app_id: "com.hnc.Discord"
    - app_id: "org.telegram.desktop"
    - app_id: "com.apple.MobileSMS"
    - app_id: "net.whatsapp.WhatsApp"
  prompt: |
    额外规则：
    - 保持口语化，不要过度正式
    - 简短直接，不需要复杂格式
    - 可以保留轻微的语气（但去掉无意义口头禅）

ai_chat:
  match_rules:
    - app_id: "com.openai.chat"
    - window_title_contains: "ChatGPT"
    - window_title_contains: "Claude"
    - window_title_contains: "Cursor"
  prompt: |
    额外规则：
    - 这是用户在跟 AI 助手对话的 prompt
    - 保留用户的指令意图和结构
    - 可以帮助组织成更清晰的指令格式
    - 不要改变技术术语

document:
  match_rules:
    - app_id: "com.apple.Notes"
    - app_id: "notion.id"
    - app_id: "md.obsidian"
    - app_id: "com.microsoft.Word"
  prompt: |
    额外规则：
    - 使用段落结构
    - 重要概念加粗（Markdown 格式）
    - 列表使用 Markdown 格式

default:
  prompt: |
    额外规则：
    - 输出清晰、通顺的文本
    - 根据内容自行判断合适的格式
```

---

## 6. 开发流程（使用 Claude Code + OpenSpec）

### 6.1 环境准备

```bash
# 1. 在 GitHub 上新建空仓库 open-typeless（MIT 协议）

# 2. Clone 到本地
git clone https://github.com/<你的用户名>/open-typeless.git
cd open-typeless

# 3. 搭建 monorepo 骨架
mkdir -p engine/open_typeless/prompts
mkdir -p engine/tests
mkdir -p clients/macos
mkdir -p clients/windows
mkdir -p clients/linux
mkdir -p docs

# 4. 把 Pindrop 代码复制进来
cd /tmp
git clone https://github.com/watzon/pindrop.git
cp -r /tmp/pindrop/* ~/open-typeless/clients/macos/
cd ~/open-typeless

# 5. 在 clients/macos/README.md 顶部添加致谢
# "Based on [Pindrop](https://github.com/watzon/pindrop) by @watzon, MIT License"
# 保留 clients/macos/LICENSE 文件

# 6. 初始提交
git add .
git commit -m "Initial monorepo structure with Pindrop as macOS client base"
git push

# 7. 安装 OpenSpec
npm install -g @fission-ai/openspec
openspec init
# 选择 Claude Code 作为 AI agent

# 8. 让 AI 自动填写 project.md
# 在 Claude Code 中：
# "请读取整个仓库结构，特别是 clients/macos 下 Pindrop 的代码，
#  帮我填写 openspec/project.md"
```

### 6.2 开发阶段一：核心引擎（约 1 周）

目标：引擎可以通过 CLI 和 HTTP 两种方式工作，接收音频文件 + 场景信息，返回润色后的文本。

**Proposal 顺序：**

```
# Proposal 1：引擎项目骨架
/opsx:propose "[engine] Bootstrap Python project with pyproject.toml,
HTTP server on localhost:19823, CLI entry point,
and health check endpoint"

# Proposal 2：STT 调用层
/opsx:propose "[engine] Add cloud STT service supporting
Groq Whisper and Deepgram APIs with audio upload"

# Proposal 3：LLM 调用层
/opsx:propose "[engine] Add OpenRouter LLM integration
with streaming support and configurable model selection"

# Proposal 4：Prompt 路由系统
/opsx:propose "[engine] Add context-aware prompt routing system
with YAML-based template configuration and
app context to scene mapping"

# Proposal 5：组装完整管线
/opsx:propose "[engine] Wire up the full polish pipeline:
audio → STT → prompt assembly → LLM → response,
exposed via POST /polish endpoint and CLI command"
```

**每个 Proposal 的操作流程：**
1. 执行 `/opsx:propose "..."` → OpenSpec 生成 proposal + specs + design + tasks
2. 审核生成的文档，确认技术方案合理
3. 执行 `/opsx:apply` → AI agent 按 spec 实现代码
4. 测试（用 curl 或 CLI 验证）
5. 执行 `/opsx:archive` → 归档，进入下一个 proposal

**阶段一完成标志：**
```bash
# CLI 模式可用
open-typeless polish recording.wav --context '{"app_id":"com.apple.mail"}'
# 输出润色后的邮件格式文本

# HTTP 模式可用
curl -X POST http://localhost:19823/polish \
  -H "Content-Type: application/json" \
  -d '{"audio_base64":"...","context":{"app_id":"com.apple.mail"}}'
# 返回润色后的 JSON 响应
```

### 6.3 开发阶段二：macOS 客户端改造（约 1 周）

目标：Pindrop 的录音完成后，不走本地 WhisperKit 转录，而是调用引擎 HTTP API，拿回润色结果粘贴到光标。

**Proposal 顺序：**

```
# Proposal 6：引擎客户端
/opsx:propose "[macos] Add EngineClient service that communicates
with the Python engine via HTTP on localhost:19823,
with health check and error handling"

# Proposal 7：场景检测
/opsx:propose "[macos] Add ActiveAppDetector that reads
frontmost app bundle ID and window title via
NSWorkspace and Accessibility API"

# Proposal 8：替换转录流程
/opsx:propose "[macos] Replace Pindrop's local WhisperKit
transcription flow with engine-based polish:
record audio → send to engine with app context →
receive polished text → paste to cursor"

# Proposal 9：设置界面
/opsx:propose "[macos] Add settings view for OpenRouter API key,
model selection, and custom prompt template editing"
```

**阶段二完成标志：**
- 按下快捷键 → 说话 → 松开 → 润色后的文字出现在光标位置
- 在 Mail 中听写自动用邮件格式，在 Slack 中听写自动用口语风格

### 6.4 开发阶段三：提升含金量（可选，约 1-2 周）

这些功能不影响核心使用，但会显著提升项目的技术深度。

```
# Level 2：风格记忆系统
/opsx:propose "[engine] Add style memory system using SQLite
to cache past polished results as few-shot examples,
with vector similarity matching for example selection"

# Level 3：边录边传优化
/opsx:propose "[engine] Add WebSocket-based streaming audio upload
to STT, reducing end-to-end latency by starting
transcription while user is still speaking"

# Level 4：输入框上下文感知
/opsx:propose "[macos] Read existing text in active input field
via Accessibility API and include as context
for more coherent continuation"
```

---

## 7. 成本估算

假设日均听写 30 分钟（约 900 分钟/月）：

| 项目 | 成本 |
|------|------|
| STT（Groq Whisper） | ~$3.6/月 |
| LLM（MiniMax M2.7 via OpenRouter） | ~$0.06/月 |
| LLM（MiniMax M2.5 free） | $0/月 |
| **总计（使用付费模型）** | **~$3.7/月** |
| **总计（使用免费模型）** | **~$3.6/月** |
| Typeless Pro 对比 | $12-30/月 |

---

## 8. 延迟预期

目标：用户松开按键后 300-650ms 内文字出现。

| 阶段 | 耗时 | 说明 |
|------|------|------|
| 音频上传到 STT | 50-100ms | 如果实现边录边传，大部分音频已在说话时处理完 |
| STT 转录 | 200-500ms | Groq Whisper 对短音频约 200ms |
| 本地 HTTP 通信 | <5ms | localhost 通信可忽略 |
| LLM 润色（等完整结果） | 150-250ms | 短文本润色，选低延迟模型 |
| 剪贴板粘贴 | <10ms | 一次性操作 |
| **总计** | **~400-865ms** | |


