# OpenTypeless TODO

> 项目待办事项，按优先级排列。完成后打勾。

## P0 — Blockers

- [x] **修复 remote STT 模式录音失败** — AppCoordinator 加 sttMode 分支，remote 跳过 WhisperKit；修复 Engine 启动 race condition（await）；EngineTranscriptionEngine 加 WAV header 转换；EngineProcessManager 移除 --host 参数
- [x] **Dock 图标不显示** — 窗口打开时 setActivationPolicy(.regular)，关闭时按需恢复 .accessory
- [x] **Engine & AI 设置页首次打开闪退** — loadPresets() 从 .task 移到 .onAppear，修复 SwiftData modelContext environment 时序问题

## P1 — 清理无效/遗留功能

- [ ] **移除 AI Enhancement 设置页** — 用户可编辑的 prompt 从未发送到 Engine，Engine 使用内置场景 prompt，此 UI 误导用户
- [ ] **清理 Notes prompt 残留** — NotesStore/UI 已删但 `AIEnhancementSettingsView` 中仍有 notes prompt tab
- [ ] **移除词典功能** — DictionaryView、DictionaryStore、VocabularyWord、WordReplacement、AutomaticDictionaryLearningService 及相关调用（纯客户端 word replacement，暂不需要）

## P1.5 — UI 行为修复

- [ ] **录音指示器不应常驻** — 屏幕底部的圆角矩形录音指示器（波形图）应仅在录音时显示，录音结束后隐藏，目前一直停留在屏幕上
- [ ] **状态栏菜单设置未同步** — 状态栏下拉菜单中的设置项（如 LLM 模型）未与实际 SettingsStore 同步，显示的不是用户真实配置
- [ ] **状态栏菜单功能清理** — 审查状态栏菜单中的所有选项，移除过时/无效的功能入口，确保与当前 Engine-backed 架构一致

## P2 — 功能完善

- [ ] **Engine 状态可视化** — 在客户端 UI 显示 Engine 连接状态（online/offline/error）、运行时信息，方便调试
- [ ] **i18n 补全** — Onboarding 后加的步骤（STTModeStepView、LLMConfigStepView、STTConfigStepView、CompleteStepView）缺少多语言支持
- [ ] **Onboarding UI 修复** — 部分步骤布局/交互问题
- [ ] **客户端自定义 Engine prompt** — 未来让客户端通过 API 编辑 Engine 的场景 prompt 模板

## P3 — 大方向

- [ ] **Distribution** — Engine 打包进 .app bundle（`Contents/Resources/engine/`），EngineProcessManager 优先从 bundle 内启动，用户无需手动启动 Engine。打包交付方案（Homebrew / DMG），需要 Apple Developer 证书
- [ ] **Custom Context Rules** — 用户自定义场景匹配规则
- [ ] **Engine 本地 STT fallback** — 非 Apple 平台（Linux/Windows）的本地 STT 支持
