## Why

`POST /polish` 目前支持两种输入模式：`text`（本地 STT 后传文本）和 `audio_base64`（传音频让 Engine 做 STT + 润色）。macOS 客户端始终使用 WhisperKit 本地转写后调 `text` 模式，`audio_base64` 从未被调用过。保留这条死路径增加了 Engine 的维护负担和 API 的认知复杂度。

## What Changes

- **BREAKING**: 移除 `/polish` 端点的 `audio_base64` 和 `audio_format` 字段，`text` 变为必填
- 移除 Engine 中 `/polish` 的 STT 分支（base64 解码 → 转写 → 润色）
- 移除相关 Engine 测试（audio_base64 的 happy path、validation、error cases）
- 更新 `docs/api-contract.md` 反映简化后的接口
- Engine `/transcribe` 端点不受影响，仍然是独立的 STT 入口

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `polish-pipeline`: 移除 audio_base64 输入模式，`text` 变为必填字段

## Impact

- **Engine**: `server.py`（移除 audio 分支逻辑）、`models.py`（移除 audio_base64/audio_format 字段）、`tests/test_server.py`（移除 audio 相关测试）
- **Client**: 无代码变更（从未使用 audio_base64）
- **文档**: `docs/api-contract.md` 更新 `/polish` 请求/响应定义
- **API 版本**: 这是 breaking change，但当前无外部消费者，影响为零
