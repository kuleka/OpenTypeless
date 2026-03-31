## Context

`POST /polish` 当前接受两种互斥输入：`text`（纯文本）或 `audio_base64`（base64 音频）。audio 分支会在 Engine 内先调 STT 转写再润色。macOS 客户端始终使用 WhisperKit 本地转写，只调 `text` 模式。`audio_base64` 是 Phase 1 设计时预留的"远程 STT + 润色一步到位"能力，但实际从未使用。

相关文件：
- `engine/open_typeless/server.py` — `/polish` 路由，含 audio 分支
- `engine/open_typeless/models.py` — `PolishRequest` 数据模型
- `engine/tests/test_server.py` — audio_base64 相关测试
- `docs/api-contract.md` — API 文档

## Goals / Non-Goals

**Goals:**
- 移除 `/polish` 的 `audio_base64` / `audio_format` 输入，`text` 变为必填
- 移除 Engine 中 `/polish` 的 STT 调用分支
- 清理相关测试和文档
- 保持 `/transcribe` 不变（独立 STT 仍然可用）

**Non-Goals:**
- 不改动 `/transcribe` 端点
- 不改动 Client 代码（Client 从未使用 audio_base64）
- 不改动 `/polish` 的输出格式
- 不移除 Engine 的 STT 配置能力（`POST /config` 的 `stt` 字段仍保留，供 `/transcribe` 使用）

## Decisions

1. **`text` 变为必填 vs 保持 Optional**
   - 选择：`text` 变为必填（`str`，不再是 `Optional[str]`）
   - 理由：移除 audio 后没有第二种输入源，Optional 没有意义
   - 替代方案：保持 Optional 但要求非空 — 增加无意义的验证逻辑

2. **移除 `stt_ms` 响应字段 vs 保留为 0**
   - 选择：移除 `stt_ms`，只保留 `llm_ms` 和 `total_ms`
   - 理由：`/polish` 不再做 STT，`stt_ms` 永远为 0，保留会误导
   - 替代方案：保留为 0 — 客户端不使用此字段，没有兼容性价值

3. **保留 `/transcribe` 不变**
   - 独立 STT 对调试和未来的非 Apple 平台有价值
   - Engine 的 STT 配置（`POST /config` 的 `stt`）仍然服务于 `/transcribe`

## Risks / Trade-offs

- **Breaking change** → 但当前无外部消费者，风险为零。API 版本在 `/health` 响应中体现。
- **未来如果需要远程 STT + 润色一步到位** → 可以通过 Client 串联 `/transcribe` + `/polish` 实现，不需要在 `/polish` 内嵌 STT。
