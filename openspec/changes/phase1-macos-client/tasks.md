## 1. EngineClient — HTTP 客户端

- [x] 1.1 创建 `EngineClient.swift`：封装 URLSession，实现 `GET /health`、`POST /config`、`GET /config` 调用
- [x] 1.2 实现 `POST /transcribe`（multipart/form-data 音频上传）
- [x] 1.3 实现 `POST /polish`（Phase 1 使用 text 输入模式，支持 translate 相关 options）
- [x] 1.4 定义 Engine 请求/响应 model（HealthResponse、ConfigRequest、TranscribeResponse、PolishRequest、PolishResponse、ErrorResponse）
- [x] 1.5 实现错误处理：连接失败、HTTP 错误码映射（NOT_CONFIGURED、STT_NOT_CONFIGURED、STT_FAILURE、LLM_FAILURE）
- [x] 1.6 编写 EngineClient 单元测试（mock URLProtocol）

## 2. Dual-Mode Transcription — 转写双模式

- [x] 2.1 创建 `EngineTranscriptionEngine.swift`：实现 `TranscriptionEngine` protocol，通过 EngineClient 调用 `/transcribe`
- [x] 2.2 在 `SettingsStore` 新增 `sttMode` 属性（枚举：local / remote）
- [x] 2.3 改造 `TranscriptionService` 的引擎选择逻辑：根据 `sttMode` 选择 local engine 或 EngineTranscriptionEngine
- [x] 2.4 编写 EngineTranscriptionEngine 单元测试

## 3. PolishService — Engine 润色服务

- [x] 3.1 创建 `PolishService.swift`：封装 `/polish` 调用，接收文本 + AppContext，返回润色结果
- [x] 3.2 实现 translate 任务支持（task + output_language 参数）
- [x] 3.3 实现错误降级：LLM_FAILURE 时提供 raw transcript 作为 fallback
- [x] 3.4 编写 PolishService 单元测试

## 4. AppCoordinator 管线改造

- [x] 4.1 在启动流程中添加 Engine 连接检查（health → config 推送）
- [x] 4.2 改造 `stopRecordingAndTranscribe()` 流程：录音 → STT（本地或远程）→ PolishService → 输出
- [x] 4.3 替换 AIEnhancementService 调用为 PolishService 调用
- [x] 4.4 处理 Engine 离线场景：本地 STT 可用但无法润色时的 UI 提示
- [x] 4.5 确保 context（app_id、window_title）正确传递到 PolishService

## 5. Settings UI — 设置界面改造

- [x] 5.1 在 `SettingsStore` 新增 Engine 配置属性（host、port、stt provider、llm provider 的 api_base/api_key/model）
- [x] 5.2 实现 API key Keychain 存储（STT key、LLM key）
- [x] 5.3 创建 Engine 连接设置 UI（host、port、连接状态指示）
- [x] 5.4 创建 STT 模式选择 UI（Local / Remote 切换，联动显示对应配置项）
- [x] 5.5 创建 STT provider 配置 UI（api_base、api_key、model，含 Groq/OpenAI/Deepgram 预设下拉）
- [x] 5.6 创建 LLM provider 配置 UI（api_base、api_key、model，含 OpenRouter/OpenAI/Ollama 预设下拉）
- [x] 5.7 实现配置变更时自动推送 `POST /config` 到 Engine

## 6. 集成测试与验收

- [ ] 6.1 端到端测试：本地 STT → Engine polish → 粘贴输出
- [ ] 6.2 端到端测试：远程 STT → Engine polish → 粘贴输出
- [ ] 6.3 测试 Engine 离线时的降级行为
- [ ] 6.4 测试设置变更后配置自动推送
- [ ] 6.5 验证现有功能不退化（热键、浮动指示器、历史记录）
