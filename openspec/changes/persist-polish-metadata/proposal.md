## Why

Engine `/polish` 响应中包含 `llm_ms`、`total_ms`、`context_detected` 等有用的元数据，但客户端在消费后完全丢弃了这些信息。用户无法在历史记录中看到每次润色的耗时或 Engine 检测到的场景（如 email）。持久化这些数据并在 HistoryView 中展示，帮助用户了解润色性能和场景匹配效果。

## What Changes

- `PolishResult` 新增 `llmMs` 和 `totalMs` 字段，从 `PolishResponse` 映射
- `RecordingPolishOutcome` 新增 `polishMs` 和 `contextDetected` 字段
- `TranscriptionRecord` SwiftData 模型新增 `polishMs: Int?` 和 `contextDetected: String?`（V6 schema migration）
- `RecordingCoordinator` 在保存历史记录时传递新字段
- `HistoryView` metadata 行展示润色耗时（追加到 LLM 模型名后）和场景图标（非 default 时显示）

## Capabilities

### New Capabilities
- `polish-metadata-persistence`: 润色元数据（耗时、场景）的持久化存储与历史记录展示

### Modified Capabilities

## Impact

- **客户端数据模型**: `TranscriptionRecordSchema.swift`（新 schema V6 + 轻量迁移）
- **客户端服务层**: `PolishService.swift`、`RecordingCoordinator.swift`、`CoordinatorTypes.swift`
- **客户端存储**: `TranscriptionHistoryStore.swift`（save 方法扩展参数）
- **客户端 UI**: `HistoryView.swift`（metadata 行扩展）
- **无 Engine 端改动**: 数据已由 Engine 返回，只需客户端存储和展示
