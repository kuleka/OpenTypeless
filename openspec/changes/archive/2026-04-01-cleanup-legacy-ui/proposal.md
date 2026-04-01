## Why

macOS 客户端继承了大量 Pindrop 遗留功能，这些功能在 Engine-backed 架构下已失效或误导用户：
- AI Enhancement 设置页中的用户可编辑 prompt 从未发送到 Engine（Engine 使用内置场景 prompt），误导用户以为可以自定义
- Notes prompt tab 是已删除 Notes 子系统的残留
- Prompt preset 管理（PromptPresetStore、PresetManagementSheet）对应的功能不存在
- 词典功能（DictionaryView、DictionaryStore、VocabularyWord、WordReplacement、AutomaticDictionaryLearningService）是纯客户端 word replacement，当前不需要
- 状态栏菜单中有过时的设置项，与实际配置不同步

清理这些可以减少约 3000+ 行无效代码，消除用户困惑，简化维护。

## What Changes

- **精简 Engine & AI 设置页**：保留 Engine 连接、STT 模式/配置、LLM 配置、Vibe Mode 等有效功能；移除用户可编辑的 enhancement prompt 编辑器、Notes prompt tab、preset 管理相关 UI
- **移除词典功能**：删除 DictionaryView、DictionaryStore、VocabularyWord、WordReplacement、AutomaticDictionaryLearningService 及所有引用（MainWindow 导航项、GeneralSettings toggle、RecordingCoordinator 调用、SwiftData schema）
- **清理状态栏菜单**：移除过时/无效的菜单项，确保剩余项与 SettingsStore 同步

## Capabilities

### New Capabilities
- `settings-cleanup`: 精简 Engine & AI 设置页，移除无效 prompt 编辑和 preset 管理
- `dictionary-removal`: 完整移除词典功能及所有依赖
- `statusbar-cleanup`: 清理状态栏菜单过时功能项

### Modified Capabilities

（无现有 spec 需要修改）

## Impact

- **UI**：Engine & AI 设置页精简（移除 prompt 编辑区域和 preset 管理）、主窗口移除 Dictionary 导航项、General 设置移除词典 toggle、状态栏菜单精简
- **数据模型**：SwiftData schema 移除 VocabularyWord、WordReplacement（需要处理 migration）
- **协调器**：AppCoordinator 移除 dictionaryStore 和 automaticDictionaryLearningService 依赖；RecordingCoordinator 移除 dictionary replacement 调用
- **删除文件**：DictionaryView、DictionaryStore、VocabularyWord、WordReplacement、AutomaticDictionaryLearningService、PresetManagementSheet（约 6 个文件）
- **修改文件**：AIEnhancementSettingsView、SettingsWindow、MainWindow、AppCoordinator、RecordingCoordinator、SettingsStore、OpenTypelessApp、GeneralSettingsView、StatusBarController 等
