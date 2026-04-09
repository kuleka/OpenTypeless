## Context

现有 E2E 测试 `EngineE2ETests` 直接用 `Process` 启动 venv python，手动管理进程生命周期。EngineProcessManager 的测试则完全基于 mock（mock healthCheck、pushConfig 闭包），从未启动真实 Engine 进程。

刚完成的 bundle-engine-binary 变更引入了 `engine/dist/open-typeless` 独立二进制和 Priority 0 发现逻辑，但没有对应的 E2E 验证。

## Goals / Non-Goals

**Goals:**

- 验证 bundled binary 能通过 E2E 正常启动、响应请求
- 验证 Engine 崩溃后 EngineProcessManager 能自动重启并恢复
- 验证 EngineProcessManager 驱动的完整生命周期（发现 → 启动 → health → config → polish）
- 测试基础设施支持 venv 和 bundled binary 两种路径，缺失时自动 skip

**Non-Goals:**

- 不测试真实 STT/LLM API（继续使用 `--stub` 模式）
- 不测试 UI 层（Onboarding、StatusBar 等）
- 不测试端口冲突等边界场景
- 不改变现有 EngineE2ETests 的 venv 测试用例

## Decisions

### 1. 测试文件组织

新增测试写在 `EngineE2ETests.swift` 同文件中，扩展现有 `@Suite`。原因：
- 共享 `launchEngine()`、`waitForHealthy()` 等基础设施
- 保持 E2E 测试集中在一个文件，便于统一管理执行顺序（`@Suite(.serialized)`）

替代方案：拆分为多个文件。否决原因：E2E 测试数量仍然较少（<15 个），拆分增加维护负担。

### 2. Bundled binary 发现方式

测试中通过 `repoRoot().appendingPathComponent("engine/dist/open-typeless")` 查找 bundled binary，与 EngineProcessManager 中的 `Bundle.main.resourceURL` 路径不同（测试环境的 Bundle.main 不是 app bundle）。这是有意为之——测试验证的是 binary 本身能工作，不是 Bundle 路径解析逻辑。

### 3. 崩溃恢复测试策略

用真实 EngineProcessManager（但注入 test configuration）启动 Engine，然后通过 `kill(pid, SIGKILL)` 模拟崩溃。验证 manager 重新 spawn 进程并恢复 healthy。

需要让 EngineProcessManager 的 `resolveEngineBinary()` 在测试中指向 venv/bundled binary 而非 Bundle.main。方式：通过已有的 `EngineProcessManager.Configuration` 设置 `customBinaryPath`（Priority 1）指向测试用的 binary 路径。

### 4. 完整生命周期测试策略

创建一个真实的 EngineProcessManager 实例，配置 `customBinaryPath` 指向可用的 Engine binary + `--stub` 参数。调用 `start()` 后等待状态变为 ready，然后通过 EngineClient 发送 polish 请求验证端到端可用。

关键：EngineProcessManager 内部的 `pushConfig()` 需要真实的配置数据才能成功。测试需要提供一个返回有效 `ConfigRequest` 的 `configProvider` 闭包。

### 5. 端口分配

各测试用不同端口避免冲突：
- 现有 venv 测试：29823
- Bundled binary 测试：29824
- 崩溃恢复测试：29825
- 完整生命周期测试：29826

## Risks / Trade-offs

- **冷启动时间**：PyInstaller bundled binary 首次启动需要解压，可能需要 8-15 秒。测试超时设为 15 秒。→ 如果 CI 环境更慢可能需要调整。
- **测试稳定性**：进程级测试天然比 mock 测试更不稳定（端口占用、进程残留等）。→ 每个测试 defer 中确保 terminate，使用不同端口。
- **依赖构建产物**：bundled binary 测试依赖 `engine/dist/open-typeless` 已构建。→ 不存在时 skip，不阻塞其他测试。
