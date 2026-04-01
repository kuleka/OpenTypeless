## REMOVED Requirements

### Requirement: AI Enhancement toggle in status bar
状态栏菜单中有 AI Enhancement 开关。
**Reason**: Enhancement prompt 编辑功能已移除，此开关对应的功能不再由客户端控制。
**Migration**: 无。

#### Scenario: No AI Enhancement toggle
- **WHEN** 用户点击状态栏图标打开菜单
- **THEN** 菜单不显示 AI Enhancement 开关

### Requirement: Prompt Preset selector in status bar
状态栏菜单中有 Prompt Preset 选择子菜单。
**Reason**: Preset 管理功能已移除。
**Migration**: 无。

#### Scenario: No Prompt Preset selector
- **WHEN** 用户点击状态栏图标打开菜单
- **THEN** 菜单不显示 Prompt Preset 选择器

### Requirement: Select AI Model submenu in status bar
状态栏菜单中有 Select AI Model 子菜单。
**Reason**: LLM 模型选择已在 Engine & AI 设置页中完成，状态栏重复且未同步。
**Migration**: 用户通过 Engine & AI 设置页配置模型。

#### Scenario: No AI Model submenu
- **WHEN** 用户点击状态栏图标打开菜单
- **THEN** 菜单不显示 Select AI Model 子菜单

## ADDED Requirements

### Requirement: Status bar menu reflects current state
状态栏菜单中保留的设置项 SHALL 与 SettingsStore 实际值同步显示。

#### Scenario: Menu items match settings
- **WHEN** 用户修改了设置（如 STT 模式、语言）
- **THEN** 状态栏菜单中对应项显示更新后的值
