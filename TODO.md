# OpenTypeless TODO

> 项目待办事项，按优先级排列。完成后打勾。

## P0 — Blockers

- [x] **修复 remote STT 模式录音失败** — AppCoordinator 加 sttMode 分支，remote 跳过 WhisperKit；修复 Engine 启动 race condition（await）；EngineTranscriptionEngine 加 WAV header 转换；EngineProcessManager 移除 --host 参数
- [x] **Dock 图标不显示** — 窗口打开时 setActivationPolicy(.regular)，关闭时按需恢复 .accessory
- [x] **Engine & AI 设置页首次打开闪退** — loadPresets() 从 .task 移到 .onAppear，修复 SwiftData modelContext environment 时序问题

## P1 — 清理无效/遗留功能

- [x] **精简 Engine & AI 设置页** — 移除无效的 prompt 编辑器、Notes prompt tab、preset 管理 UI；保留 Engine 连接、STT/LLM 配置、Vibe Mode
- [x] **清理 Notes prompt 残留** — 移除 PromptType enum、noteEnhancementPrompt、相关 state 和方法
- [x] **移除词典功能** — 删除 DictionaryView、DictionaryStore、VocabularyWord、WordReplacement、AutomaticDictionaryLearningService 及所有引用
- [x] **移除 PromptPreset 系统** — 删除 PromptPreset model、PromptPresetStore、PresetManagementSheet 及 SwiftData schema 引用

## P1.5 — UI 行为修复

- [x] **录音指示器不应常驻** — PillFloatingIndicator.showIdleIndicator() 改为调用 hide()，录音结束后隐藏
- [x] **Engine & AI tab 打开时焦点跳走** — loadSettingsState/refreshPermissionStates 从 .onAppear 移到 .task，避免 Keychain/AXIsProcessTrusted 同步调用抢焦点
- [x] **设置页文本框无法拖拽选中内容** — `isMovableByWindowBackground = true` 导致拖拽优先移动窗口，已改为 false
- [x] **状态栏菜单功能清理** — 移除 AI Enhancement toggle、Prompt Preset selector、Select AI Model submenu 及相关回调

## P2 — 功能完善

- [ ] **Engine 状态可视化** — 在客户端 UI 显示 Engine 连接状态（online/offline/error）、运行时信息，方便调试
- [ ] **i18n 补全** — Onboarding 后加的步骤（STTModeStepView、LLMConfigStepView、STTConfigStepView、CompleteStepView）缺少多语言支持
- [ ] **Onboarding UI 修复** — 部分步骤布局/交互问题
- [ ] **客户端自定义 Engine prompt** — 未来让客户端通过 API 编辑 Engine 的场景 prompt 模板

## P3 — 大方向

- [ ] **Distribution** — Engine 打包进 .app bundle（`Contents/Resources/engine/`），EngineProcessManager 优先从 bundle 内启动，用户无需手动启动 Engine。打包交付方案（Homebrew / DMG），需要 Apple Developer 证书
- [ ] **Custom Context Rules** — 用户自定义场景匹配规则
- [ ] **Engine 本地 STT fallback** — 非 Apple 平台（Linux/Windows）的本地 STT 支持
