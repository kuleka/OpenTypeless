## Context

Pindrop 是一个成熟的 macOS 语音输入工具（~15,000 行 Swift），架构以 `AppCoordinator` 为核心，协调录音、转写、AI 润色、输出等服务。当前所有逻辑在 Client 内完成：WhisperKit/Parakeet 做本地 STT，`AIEnhancementService` 直接调 Claude API 做润色。

OpenTypeless 要求 Client 变为薄壳，将 STT（可选）和 LLM 润色委托给独立的 Engine HTTP 服务（`http://127.0.0.1:19823`）。Engine 已在 `phase1-core-engine` 分支开发，遵循 `docs/api-contract.md` v1.4.0。

Client 需要在**保留现有本地 STT 能力**的同时，新增远程 STT 支持，并将所有 LLM 润色统一通过 Engine `/polish` 完成。

## Goals / Non-Goals

**Goals:**

- Client 通过 Engine `/polish` 完成所有文本润色（替代直接调 LLM API）
- 支持双模式 STT：本地 WhisperKit/Parakeet（保留）或远程 Engine `/transcribe`
- 用户可在设置 UI 中配置 Engine 连接、STT 模式、STT/LLM provider
- 启动时自动检测 Engine 可用性并推送配置
- 保持现有用户体验不退化（热键、浮动指示器、粘贴输出）

**Non-Goals:**

- 不改造 Engine（Engine 开发在 `phase1-core-engine` 分支独立进行）
- 不新增流式转写支持（Phase 3）
- 不修改 HotkeyManager、AudioRecorder、OutputManager、ContextEngineService
- 不改动 Pindrop 的数据模型（TranscriptionRecord、Notes 等）
- 不做 UI 大改版，只在现有设置框架上增加 Engine 相关配置

## Decisions

### 1. HTTP 客户端用 Foundation URLSession，不引入第三方库

**选择**：使用 Swift 原生 `URLSession` async/await API。

**替代方案**：Alamofire 或其他网络库。

**理由**：Engine 运行在本地 localhost，请求简单（JSON POST + multipart），不需要复杂的网络栈。URLSession 足够，且零外部依赖。

### 2. PolishService 完全替代 AIEnhancementService

**选择**：新建 `PolishService`，所有 LLM 润色走 Engine `/polish`。无论 STT 是本地还是远程，Client 都先拿到 transcript，再以 `text` 模式调用 `/polish`。`AIEnhancementService` 代码保留但不再被调用（后续清理）。

**替代方案**：在 `AIEnhancementService` 内部切换后端（直接调 API vs 走 Engine）。

**理由**：`AIEnhancementService` 承担了太多职责（context 组装、prompt 构建、API 调用、mention 改写），且与 Claude API 深度耦合。新建 `PolishService` 更干净，职责单一：把 transcript + 上下文打包发给 Engine，拿回结果。远程 STT 也先显式调用 `/transcribe`，这样 Client 能稳定拿到 raw transcript，便于展示、回退和测试。

### 3. TranscriptionService 保持 Protocol 抽象，新增 RemoteEngine 作为一种引擎

**选择**：在现有 `TranscriptionEngine` protocol 体系下新增 `EngineTranscriptionEngine`，实现远程 STT。`TranscriptionService` 根据用户设置选择引擎。

**替代方案**：在 `TranscriptionService` 层面做 if/else 分支。

**理由**：Pindrop 已有良好的引擎抽象（WhisperKitEngine、ParakeetEngine）。新增一个远程引擎符合已有模式，最小改动。

### 4. 设置存储复用 SettingsStore + UserDefaults

**选择**：在 `SettingsStore` 中新增 Engine 相关配置属性（engine_host、engine_port、stt_mode、stt_provider、llm_provider 等）。

**替代方案**：独立的 EngineSettings 存储。

**理由**：Pindrop 所有设置都在 `SettingsStore` 中用 `@AppStorage` 管理，保持一致性。API Key 继续用 Keychain 存储（与现有 AI API key 存储方式一致）。

### 5. Engine 连接管理放在 AppCoordinator 启动流程中

**选择**：`AppCoordinator` 启动时依次执行 `GET /health` → `POST /config`。Engine 不可用时 Client 仍可工作（本地 STT 模式，但无法润色）。

**替代方案**：独立的 EngineConnectionManager 服务。

**理由**：连接逻辑简单（两个 HTTP 调用），不值得单独抽服务。放在 AppCoordinator 的启动序列中，与现有的权限检查、模型加载等初始化逻辑并列。

### 6. Context 采集逻辑保留在 Client 端

**选择**：Client 继续使用 `ContextEngineService` 采集 app context（bundle ID、window title），在请求 `/polish` 时作为 `context` 字段传入。

**理由**：Context 采集需要 macOS Accessibility API，只能在 Client 端完成。Engine 只负责根据 context 做场景匹配。

## Risks / Trade-offs

- **Engine 未启动时的降级体验** → 本地 STT 仍可用，但无法润色。UI 显示 Engine 离线状态，引导用户启动 Engine。若用户选择远程 STT 模式且 Engine 不可用，录音后提示错误。
- **AIEnhancementService 的 context 组装能力丢失** → 现有的 AIEnhancementService 会把剪贴板内容、workspace 文件树、chat history 等丰富上下文发给 Claude。迁移到 Engine `/polish` 后，context 只有 `app_id` 和 `window_title`。这是设计上的取舍——Engine 做场景检测不需要这些细粒度上下文。未来可在 `/polish` 请求中扩展 context 字段。
- **双模式增加测试复杂度** → 需要分别测试本地 STT + Engine polish、远程 STT + Engine polish 两条路径。Mock Engine 响应可降低测试难度（参考 api-contract.md 的 Mock 示例）。
