## Context

macOS 客户端从 Pindrop 继承了大量功能，在迁移到 Engine-backed 架构后，部分 UI 和功能已失效。当前状态：

- **AIEnhancementSettingsView** 既包含有效功能（Engine 连接、STT/LLM 配置、Vibe Mode），也包含无效功能（prompt 编辑器、Notes prompt tab、preset 管理）
- **词典功能**（6 个文件）深度集成在 AppCoordinator、RecordingCoordinator、SwiftData schema 中
- **状态栏菜单** 包含过时选项，部分设置项未与 SettingsStore 同步

## Goals / Non-Goals

**Goals:**
- 从 AIEnhancementSettingsView 移除无效的 prompt 编辑和 preset 管理 UI，保留所有 Engine/STT/LLM 配置功能
- 完整移除词典功能（UI、数据模型、服务、所有引用）
- 清理状态栏菜单中过时的功能项
- 确保编译通过，无运行时回归

**Non-Goals:**
- 不重新设计 Engine & AI 设置页布局（只做减法）
- 不修改 Engine 端代码
- 不处理 i18n 或 Onboarding UI 问题（属于其他 TODO）
- 不新增功能

## Decisions

### 1. AIEnhancementSettingsView：就地精简 vs 重写

**选择：就地精简**——删除 promptsCard 及相关代码（PromptType enum、prompt 编辑器、preset 选择器、loadPresets/savePresets），保留 enableToggleCard、providerCard、contextCard。

理由：视图结构已经按卡片拆分（enableToggleCard、providerCard、promptsCard、contextCard），直接移除 promptsCard 和相关 state/方法即可，不需要重写。

### 2. 词典 SwiftData migration

**选择：从 schema 中移除 VocabularyWord 和 WordReplacement，依赖 SwiftData 轻量级 migration**。

理由：这两个模型只有词典功能使用，移除后 SwiftData 会在下次启动时自动处理 schema 变更（轻量级 migration 支持删除 model）。如果用户之前有词典数据会自动丢弃，这是预期行为。

### 3. 状态栏菜单清理策略

**选择：逐项审查，移除引用已删功能的项**——具体移除 AI Enhancement toggle、Prompt Preset selector、Select AI Model submenu（这些直接对应被删功能）。保留录音、转录、输出等核心功能项。

## Risks / Trade-offs

- **SwiftData schema 变更** → 轻量级 migration 通常能处理删除 model 的情况；如果出问题，最坏情况是用户需要重置 app data（可接受，因为关键数据只有 TranscriptionRecord）
- **遗漏引用导致编译失败** → 每删一个文件后立即编译验证，逐步推进
- **状态栏功能判断失误** → 只移除明确对应已删功能的项，不确定的保留
