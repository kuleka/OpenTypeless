## REMOVED Requirements

### Requirement: User-editable enhancement prompt
用户可在 Engine & AI 设置页编辑 transcription prompt 和 notes prompt。
**Reason**: Engine 使用内置场景 prompt，客户端编辑的 prompt 从未发送到 Engine，此功能误导用户。
**Migration**: 无需迁移，用户编辑的 prompt 无实际作用。

#### Scenario: Prompt editor not shown
- **WHEN** 用户打开 Engine & AI 设置页
- **THEN** 页面不显示 prompt 编辑区域（promptsCard）

### Requirement: Notes prompt tab
AIEnhancementSettingsView 中有 Transcription / Notes 两个 prompt tab。
**Reason**: Notes 子系统已在 Legacy Client Cleanup 中删除，此 tab 是残留。
**Migration**: 无。

#### Scenario: No prompt type tabs
- **WHEN** 用户打开 Engine & AI 设置页
- **THEN** 页面不显示 Transcription / Notes prompt 切换 tab

### Requirement: Prompt preset management
用户可管理 prompt preset（选择、创建、删除、重置）。
**Reason**: Preset 对应的 prompt 编辑功能一并移除，preset 管理失去意义。
**Migration**: 无。PromptPreset SwiftData model 和 PresetManagementSheet 一并删除。

#### Scenario: No preset selector
- **WHEN** 用户打开 Engine & AI 设置页
- **THEN** 页面不显示 preset 选择器和管理按钮

## ADDED Requirements

### Requirement: Engine & AI settings page retains valid settings
Engine & AI 设置页 SHALL 保留以下功能卡片：
- Engine 连接设置（host、port、recheck）
- STT 模式选择（local / remote）
- STT 配置（本地模型选择 / 远程 provider 配置）
- LLM 配置（provider、API key、model）
- Vibe Mode 设置（上下文捕获开关）

#### Scenario: Valid settings accessible
- **WHEN** 用户打开 Engine & AI 设置页
- **THEN** 用户可配置 Engine 连接、STT、LLM 和 Vibe Mode
