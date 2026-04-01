## 1. 移除词典功能

- [x] 1.1 删除词典相关文件：DictionaryView.swift、DictionaryStore.swift、AutomaticDictionaryLearningService.swift、VocabularyWord.swift、WordReplacement.swift
- [x] 1.2 从 MainWindow.swift 移除 .dictionary 导航项（MainNavItem enum、primaryNavigationItems、icon mapping、content switch）
- [x] 1.3 从 AppCoordinator.swift 移除 dictionaryStore 和 automaticDictionaryLearningService 属性及初始化
- [x] 1.4 从 RecordingCoordinator.swift 移除 dictionaryStore 和 automaticDictionaryLearningService 引用（属性、init 参数、replacement 调用、learning 调用）
- [x] 1.5 从 OpenTypelessApp.swift 和 TranscriptionRecordSchema.swift 的 SwiftData schema 移除 VocabularyWord.self 和 WordReplacement.self
- [x] 1.6 从 GeneralSettingsView.swift 移除 dictionarySection 和 automaticDictionaryLearningEnabled toggle
- [x] 1.7 从 SettingsStore.swift 移除 automaticDictionaryLearningEnabled 属性
- [x] 1.8 从 PreviewMocks.swift 移除词典相关 model 引用
- [x] 1.9 编译验证词典移除无误

## 2. 精简 Engine & AI 设置页

- [x] 2.1 从 AIEnhancementSettingsView body 移除 promptsCard
- [x] 2.2 删除 PromptType enum、promptsCard、promptTypeTabs、promptContentEditor 等 prompt 相关 UI 代码
- [x] 2.3 删除 loadPresets/savePresets、preset 选择相关 state 和方法，移除 PromptPresetStore 引用
- [x] 2.4 删除 PresetManagementSheet.swift 文件
- [x] 2.5 从 SettingsStore.swift 移除 noteEnhancementPrompt 和 Defaults.noteEnhancementPrompt
- [x] 2.6 删除 PromptPreset.swift、PromptPresetStore.swift 并从 SwiftData schema 和 AppCoordinator 移除
- [x] 2.7 编译验证设置页精简无误

## 3. 清理状态栏菜单

- [x] 3.1 从 StatusBarController.swift 移除 AI Enhancement toggle 菜单项
- [x] 3.2 从 StatusBarController.swift 移除 Prompt Preset selector 菜单项
- [x] 3.3 从 StatusBarController.swift 移除 Select AI Model submenu
- [x] 3.4 验证保留的菜单项与 SettingsStore 同步显示正确值
- [x] 3.5 编译验证状态栏清理无误

## 4. 最终验证

- [x] 4.1 全量编译通过
- [x] 4.2 更新 TODO.md 标记已完成项
