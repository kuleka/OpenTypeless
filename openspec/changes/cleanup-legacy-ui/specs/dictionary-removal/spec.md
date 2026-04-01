## REMOVED Requirements

### Requirement: Dictionary view
主窗口侧栏提供 Dictionary 导航项，用户可查看和管理词汇替换规则。
**Reason**: 纯客户端 word replacement 功能，当前不需要。
**Migration**: 无。用户词典数据将在 schema migration 时自动丢弃。

#### Scenario: Dictionary navigation removed
- **WHEN** 用户打开主窗口
- **THEN** 侧栏不显示 Dictionary 导航项

### Requirement: Dictionary store and models
DictionaryStore 提供词汇持久化，VocabularyWord 和 WordReplacement 为 SwiftData 模型。
**Reason**: 随 Dictionary 功能一并移除。
**Migration**: 从 SwiftData schema 移除 VocabularyWord 和 WordReplacement model，依赖轻量级 migration。

#### Scenario: SwiftData schema excludes dictionary models
- **WHEN** app 启动
- **THEN** ModelContainer schema 不包含 VocabularyWord 和 WordReplacement

### Requirement: Automatic dictionary learning
AutomaticDictionaryLearningService 观察转录结果并自动学习词汇替换。
**Reason**: 随 Dictionary 功能一并移除。
**Migration**: 从 RecordingCoordinator 和 AppCoordinator 移除所有引用。

#### Scenario: No dictionary replacement in transcription
- **WHEN** 用户完成一次录音转录
- **THEN** 转录流程不调用 dictionary replacement

### Requirement: Dictionary toggle in General settings
General 设置页有 Dictionary 开关。
**Reason**: 随 Dictionary 功能一并移除。
**Migration**: 从 GeneralSettingsView 移除 dictionarySection。

#### Scenario: No dictionary toggle
- **WHEN** 用户打开 General 设置页
- **THEN** 页面不显示 Dictionary 开关
