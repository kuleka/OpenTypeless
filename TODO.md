# OpenTypeless TODO

> 项目待办事项，按优先级排列。完成后打勾。

## P0 — Blockers

- [ ] **修复 remote STT 模式录音失败** — `AppCoordinator.startNormalOperation()` 无条件加载本地 WhisperKit 模型，remote 模式下 engine 为 nil 导致 `modelNotLoaded` 错误
- [ ] **Dock 图标不显示** — 设置页面打开时 Dock 栏没有 app 图标（可能是 `LSUIElement` 配置问题）

## P1 — 清理无效/遗留功能

- [ ] **移除 AI Enhancement 设置页** — 用户可编辑的 prompt 从未发送到 Engine，Engine 使用内置场景 prompt，此 UI 误导用户
- [ ] **清理 Notes prompt 残留** — NotesStore/UI 已删但 `AIEnhancementSettingsView` 中仍有 notes prompt tab
- [ ] **移除词典功能** — DictionaryView、DictionaryStore、VocabularyWord、WordReplacement、AutomaticDictionaryLearningService 及相关调用（纯客户端 word replacement，暂不需要）

## P2 — 功能完善

- [ ] **i18n 补全** — Onboarding 后加的步骤（STTModeStepView、LLMConfigStepView、STTConfigStepView、CompleteStepView）缺少多语言支持
- [ ] **Onboarding UI 修复** — 部分步骤布局/交互问题
- [ ] **客户端自定义 Engine prompt** — 未来让客户端通过 API 编辑 Engine 的场景 prompt 模板

## P3 — 大方向

- [ ] **Distribution** — Engine + App 打包交付（Homebrew / DMG），需要 Apple Developer 证书
- [ ] **Custom Context Rules** — 用户自定义场景匹配规则
- [ ] **Engine 本地 STT fallback** — 非 Apple 平台（Linux/Windows）的本地 STT 支持
