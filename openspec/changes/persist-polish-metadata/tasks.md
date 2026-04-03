## 1. 数据模型扩展

- [x] 1.1 在 `PolishService.swift` 的 `PolishResult` 中添加 `llmMs: Int?` 和 `totalMs: Int?`，在 `polish()` 成功路径映射自 `PolishResponse`，fallback 路径设为 nil
- [x] 1.2 在 `CoordinatorTypes.swift` 的 `RecordingPolishOutcome` 中添加 `polishMs: Int?` 和 `contextDetected: String?`
- [x] 1.3 在 `TranscriptionRecordSchema.swift` 中新增 V6 schema：`TranscriptionRecord` 添加 `polishMs: Int?` 和 `contextDetected: String?`，配置 `MigrationStage.lightweight` V5→V6，更新 `TranscriptionRecordMigrationPlan`

## 2. 数据流连接

- [x] 2.1 在 `RecordingCoordinator.swift` 的 `polishTranscribedTextIfNeeded` 中将 `PolishResult.totalMs` 和 `contextDetected` 传入 `RecordingPolishOutcome`（成功路径赋值，其他路径 nil）
- [x] 2.2 在 `RecordingCoordinator.swift` 的 `historyStore.save()` 调用处传递 `polishMs` 和 `contextDetected`
- [x] 2.3 在 `HistoryStore.swift` 的 `save()` 方法中添加 `polishMs: Int? = nil` 和 `contextDetected: String? = nil` 参数，传入 `TranscriptionRecord` 初始化

## 3. UI 展示

- [x] 3.1 在 `HistoryView.swift` 的 metadata 行中，为有 `polishMs` 的记录在 LLM 模型名后追加耗时（如 "via llama-3.3-70b (320ms)"）
- [x] 3.2 在 `HistoryView.swift` 的 metadata 行中，为 `contextDetected` 非 nil 且非 "default" 的记录添加场景图标和文字（envelope 图标 for email）

## 4. 验证

- [x] 4.1 构建客户端 (`xcodebuild`) 确认编译通过
- [x] 4.2 启动 App 验证 SwiftData 迁移正常（无崩溃），已有历史记录仍可显示
