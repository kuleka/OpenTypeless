## Context

Engine `/polish` 已返回 `llm_ms`、`total_ms`、`context_detected`。客户端 `PolishResponse`（EngineClient.swift）已解码这些字段，但 `PolishResult`（PolishService.swift）没有携带 timing，`RecordingCoordinator` 保存历史时也没有传递。`TranscriptionRecord` 当前在 V5 schema，使用 SwiftData `SchemaMigrationPlan`。

数据流：`EngineClient.PolishResponse` → `PolishService.PolishResult` → `RecordingCoordinator.RecordingPolishOutcome` → `TranscriptionHistoryStore.save()` → `TranscriptionRecord`。需要在每一环补上新字段。

## Goals / Non-Goals

**Goals:**
- 持久化 `polishMs`（总润色耗时）和 `contextDetected`（场景）到 TranscriptionRecord
- 在 HistoryView 展示这两个信息
- SwiftData 轻量迁移，不丢失已有数据

**Non-Goals:**
- 不持久化 `llm_ms`（内部分步耗时），只存 `total_ms` 作为用户可感知的总耗时
- 不改 Engine 端任何代码
- 不在 DashboardView 聚合统计这些数据
- 不改变 PolishService 的 fallback 逻辑

## Decisions

### 1. 存 `totalMs` 而非 `llmMs`
- **选择**: 持久化 `total_ms`（Engine 端的完整润色耗时，含 scene detection + prompt assembly + LLM 调用）
- **替代方案**: 存 `llm_ms`（纯 LLM 耗时）
- **理由**: 用户关心的是从发出请求到拿到结果的感知延迟。`total_ms` 更接近这个体验。`llm_ms` 是实现细节。

### 2. SwiftData V6 轻量迁移
- **选择**: 新增 `TranscriptionRecordSchemaV6`，两个 optional 字段，使用 `MigrationStage.lightweight`
- **替代方案**: 不做迁移，用 `@Transient` 属性
- **理由**: `@Transient` 不持久化，重启后丢失。optional 字段的轻量迁移是 SwiftData 原生支持的，零风险。

### 3. HistoryView 展示方式：追加到已有 metadata 行
- **选择**: 耗时追加到 LLM 模型名后面 `via llama-3.3-70b (320ms)`；场景用图标 + 文字显示在最后
- **替代方案**: 新建独立行展示
- **理由**: 信息量小，追加到已有行更紧凑。只在有数据时显示，不增加无 polish 记录的视觉噪音。

### 4. 场景只展示非 default
- **选择**: `contextDetected == "default"` 时不显示图标
- **理由**: 大部分请求都是 default 场景，显示没有信息量。只在检测到特定场景（如 email）时才值得展示。

## Risks / Trade-offs

- **数据不可回填**: 已有历史记录的 `polishMs` 和 `contextDetected` 为 nil → 可接受，新记录自然携带
- **PolishResult 变大**: 多两个 `Int?` 字段 → 可忽略
