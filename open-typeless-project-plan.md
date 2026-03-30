# Open Typeless — 项目规划文档

> 最后更新：2026-03-30
> 这份文档用于记录项目的长期目标、已经确认的架构决策、当前真实状态，以及下一阶段规划。

---

## 1. 项目定位

OpenTypeless 是一个开源的 Typeless 替代方案。

核心体验是：

```text
用户自然说话
  -> 语音转文字（本地或远程 STT）
  -> 基于当前应用场景进行润色
  -> 输出到当前光标位置
```

项目目标：

- 开源、可自托管、可低成本运行
- 引擎层跨平台，客户端可以逐步扩展到 macOS / Windows / Linux
- 首个完整客户端为 macOS 原生应用

---

## 2. 当前状态总览

截至目前，Phase 1 基础能力已完成并合并到 `main`，Legacy 清理也已完成：

- Python Engine 已完成
- macOS Client 的主听写链路已完成 `Client + Engine` 架构迁移
- Legacy 清理已完成：AIEnhancementService、quick capture、Notes 子系统全部删除
- OpenSpec 主线 specs 已建立，当前没有 active change

当前基线来源：

- [主线 OpenSpec specs](openspec/specs)
- [Engine ↔ Client API contract](docs/api-contract.md)
- [macOS Client Phase 1 总结](docs/macos-client-phase1.md)

当前已归档的关键 change：

- `2026-03-29-phase1-core-engine`
- `2026-03-29-engine-api-v14-upgrade`
- `2026-03-30-phase1-macos-client`

一句话总结当前状态：

```text
Phase 1 + Legacy Cleanup 已完成
  = Engine 可用 + macOS 主链路可用 + 遗留代码已清理 + OpenSpec 基线已归档
```

---

## 3. 已确认的架构决策

### 3.1 Monorepo + 本地 HTTP 边界

**决策**：Engine 和各端 Client 放在同一个仓库中，但通过 localhost HTTP 契约解耦。

**原因**：

- Engine 必须可被多个客户端复用
- Client 和 Engine 可以独立演进
- 协议边界清晰，便于测试、替换和未来多端扩展
- Monorepo 方便统一管理文档、协议、版本和贡献流程

### 3.2 Engine 语言：Python

**决策**：核心引擎使用 Python。

**原因**：

- 当前主要工作是 HTTP 编排、STT/LLM API 调用和 prompt 路由
- Python 生态对 FastAPI、httpx、测试、未来 LLM 相关扩展都更友好
- 分发和社区贡献门槛较低

### 3.3 macOS 客户端基座：Pindrop

**决策**：macOS 客户端基于 Pindrop 改造。

**原因**：

- MIT 协议，法律风险低
- 原生 Swift / SwiftUI，打包体积和系统集成都更好
- 已经具备全局热键、录音、输出、权限管理等底层能力
- 适合作为薄客户端继续演化，而不是从头重写

### 3.4 当前转写策略：双模式 STT

**决策**：Phase 1 同时保留本地 STT 和远程 STT。

当前实现是：

- **本地 STT 模式**：macOS 客户端本地转写，再将文本发给 `POST /polish`
- **远程 STT 模式**：macOS 客户端先调用 `POST /transcribe`，再用结果调用 `POST /polish`

补充说明：

- API 契约仍支持“直接把音频发给 `/polish`”这一模式
- 但当前 macOS 客户端主路径已经明确采用 `/transcribe -> /polish(text)`，这样更清晰，也更便于调试

### 3.5 Provider 策略：Engine provider-agnostic

**决策**：Engine 不写死 Groq、OpenAI、Deepgram、OpenRouter 中任何一家。

当前约束：

- `POST /config` 接收 `stt` 和 `llm` 的 `api_base / api_key / model`
- Client 负责 provider preset 和 UX
- Engine 负责按契约调用兼容接口

这意味着：

- 你可以用 Groq 做 STT，OpenRouter 做 LLM
- 也可以本地 STT + Ollama LLM
- 也可以全用 OpenAI

### 3.6 场景检测放在 Client

**决策**：前台应用检测和窗口标题采集在 Client 侧完成，Engine 只消费 `app_id` / `window_title`。

**原因**：

- 场景信息天然依赖操作系统能力
- Engine 不应该知道 macOS Accessibility 细节
- 这样 Windows / Linux 客户端未来也可以复用同一套 Engine 接口

### 3.7 输出方式：一次性输出完整结果

**决策**：润色完成后一次性输出到光标位置，不做逐字流式粘贴。

**原因**：

- 剪贴板 / 直接插入更适合最终文本结果
- 听写场景强调“完整文本一次到位”，不是聊天式 token 流

---

## 4. 当前仓库结构

下面是目前仓库里的真实结构，不是最初草案结构：

```text
OpenTypeless/
├── README.md
├── LICENSE
├── open-typeless-project-plan.md
├── docs/
│   ├── api-contract.md
│   └── macos-client-phase1.md
├── engine/
│   ├── pyproject.toml
│   ├── open_typeless/
│   │   ├── cli.py
│   │   ├── config.py
│   │   ├── context.py
│   │   ├── llm.py
│   │   ├── models.py
│   │   ├── prompt_router.py
│   │   ├── server.py
│   │   ├── stt.py
│   │   └── prompts/defaults.yaml
│   └── tests/
├── clients/
│   └── macos/
│       ├── Pindrop/
│       ├── PindropTests/
│       ├── PindropUITests/
│       ├── Pindrop.xcodeproj
│       ├── Package.swift
│       ├── README.md
│       ├── CONTRIBUTING.md
│       ├── BUILD.md
│       └── RELEASING.md
└── openspec/
    ├── specs/
    └── changes/archive/
```

需要特别注意：

- macOS 工程和 target 仍然叫 `Pindrop`
- 这是历史连续性问题，不代表项目名称还是 Pindrop

---

## 5. 当前 API 基线

**唯一协议真相**： [docs/api-contract.md](docs/api-contract.md)

当前核心端点：

- `GET /health`
- `POST /config`
- `GET /config`
- `POST /transcribe`
- `POST /polish`
- `GET /contexts`
- `POST /contexts`

当前重要约束：

- Client 启动后先 `GET /health`
- 再通过 `POST /config` 推送 LLM/STT 配置
- 本地 STT 模式：直接把文本发给 `/polish`
- 远程 STT 模式：先 `/transcribe`，再 `/polish`
- `/polish` 支持 `task=polish` 和 `task=translate`

当前 `/polish` 的语义不是“只接收音频”。
它已经是：

- 文本输入时：只做 prompt 路由和 LLM 润色
- 音频输入时：可选 STT 后再润色

---

## 6. Phase 1 已完成内容

### 6.1 Engine

已完成：

- FastAPI 本地服务
- 内存配置管理
- provider-agnostic STT
- provider-agnostic LLM
- prompt 路由与上下文组装
- `/health`、`/config`、`/transcribe`、`/polish`、`/contexts`
- pytest 测试覆盖

### 6.2 macOS Client

已完成：

- `EngineClient`
- `EngineTranscriptionEngine`
- 双模式 STT 选择
- `PolishService`
- `AppCoordinator` 主听写链路接入 Engine
- Engine host/port 与 provider 设置
- Keychain 存储 API key
- app-level tests
- settings UI smoke tests

当前主链路是：

```text
按下热键录音
  -> 本地 STT 或 Engine /transcribe
  -> 客户端字典替换 / mention rewrite
  -> Engine /polish
  -> OutputManager 输出
```

### 6.3 OpenSpec

已完成：

- Engine Phase 1 specs 归档
- macOS Phase 1 specs 归档
- 主线 `openspec/specs/` 已同步建立

这意味着从现在开始，新工作不应继续修改旧 archived change，而应该新开 change。

---

## 7. 当前仍未完成的工作

虽然 Phase 1 已完成，但项目还远没到“发布完成”状态。

当前最明显的缺口有：

### 7.1 运行时 onboarding / 交付体验

例如：

- Engine 如何被用户启动、发现、重连
- 首次配置如何更顺畅
- Engine 离线时怎样给用户明确反馈
- 最终发布时 Engine 和 macOS app 如何一起交付

### 7.2 遗留客户端流程清理 — ✅ 已完成

已清理内容：

- `AIEnhancementService` 已删除（1420 行），`LiveSessionContext` 提取为独立文件
- `quick capture note` 工作流已退役（快捷键、录音状态、笔记编辑器）
- Notes 子系统已整体删除（NotesStore、NoteSchema、NotesView、NoteCardView、NoteEditorWindow，共 ~1700 行）
- Legacy AI provider/key/model 设置 UI 已移除，统一到 Engine-backed 配置

### 7.3 用户可定制场景规则

Engine 已有 `/contexts` 接口，但用户级自定义 UI 和完整工作流还没有打通。

### 7.4 多平台客户端

Windows / Linux 仍然只是未来方向，没有启动。

---

## 8. 建议的下一阶段路线图

### 优先级 1：Runtime Onboarding / Distribution

这是我当前最推荐的下一阶段。

目标：

- 让用户拿到仓库后，能更顺滑地把 Engine 和 macOS app 跑起来
- 让“首次启动 / 配置 / 检查连接 / 故障反馈”变成明确产品流程

建议作为新的 OpenSpec change，例如：

- `phase2-runtime-onboarding`

### 优先级 2：Legacy Flow Cleanup — ✅ 已完成

已通过 `cleanup-legacy-client-flows` change 完成并归档。

### 优先级 3（现为优先级 2）：Custom Context Rules

目标：

- 让用户自定义 app 场景规则
- 让用户调整 prompt 模板
- 真正利用 `/contexts` 能力

建议 change 名，例如：

- `custom-scene-rules-and-prompts`

---

## 9. 现在如何继续使用 OpenSpec

当前仓库状态：

- `openspec/specs/` 是主线行为基线
- `openspec/changes/archive/` 保存历史实现过程
- 当前没有 active change

因此后续流程应该是：

1. 从 `main` 开新分支
2. 先阅读相关主线 specs
3. 新建一个新的 change
4. 写 proposal / design / specs / tasks
5. 实现并验证
6. 完成后 archive

推荐命令：

```bash
openspec list --json
openspec validate --specs
openspec new change <change-name>
openspec show <change-name>
openspec validate <change-name>
openspec archive <change-name>
```

原则：

- 不要继续往 archived change 里加内容
- 新需求、新范围、新清理工作都开新 change

---

## 10. 当前开发命令参考

### Engine

安装依赖后可运行：

```bash
cd engine
python -m pytest tests -v
python -m open_typeless.cli serve
```

如果已经做了 editable install，也可以直接：

```bash
open-typeless serve
```

### macOS Client

快速测试：

```bash
cd clients/macos
swift test
```

完整 app-level tests：

```bash
cd clients/macos
xcodebuild test \
  -project Pindrop.xcodeproj \
  -scheme Pindrop \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/OpenTypelessDerivedData \
  -clonedSourcePackagesDirPath /tmp/OpenTypelessSourcePackages \
  -only-testing:PindropTests \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY='' \
  DEVELOPMENT_TEAM=''
```

UI smoke tests：

```bash
cd clients/macos
xcodebuild test \
  -project Pindrop.xcodeproj \
  -scheme Pindrop \
  -testPlan UI \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/OpenTypelessUISignedDerivedData \
  -clonedSourcePackagesDirPath /tmp/OpenTypelessSourcePackages \
  CODE_SIGN_IDENTITY=- \
  AD_HOC_CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=YES \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM=''
```

---

## 11. 成本与延迟的现实判断

### 11.1 成本

当前不是“必须云端 STT + 云端 LLM”。

实际可选模式有两类：

- **本地 STT + 远程 LLM**
  优点：STT 成本接近 0，只保留 LLM 成本
- **远程 STT + 远程 LLM**
  优点：本地模型和硬件负担更低，配置更统一

如果使用：

- Groq Whisper 做 STT
- OpenRouter 上的低价模型做 polish

那月成本仍然明显低于 Typeless 商业订阅。

### 11.2 延迟

当前 Phase 1 的主链路是**批处理模式**，不是流式边录边传。

现实可接受的目标延迟大致是：

| 阶段 | 估算 |
|------|------|
| 本地或远程 STT | 200-600ms |
| localhost HTTP 与组装 | <10ms |
| LLM polish | 150-300ms |
| 输出 | <10ms |
| **总计** | **约 400-900ms** |

未来如果做 streaming STT，那是新的优化阶段，不是当前已实现能力。

---

## 12. 当前结论

这个项目已经不再处于“从零开始搭骨架”的阶段。

现在的真实阶段是：

```text
已完成：
  Engine Phase 1
  macOS Client Phase 1
  Legacy Client Cleanup（AIEnhancementService、Notes、quick capture 全部删除）
  OpenSpec baseline

下一步重点：
  端到端集成测试（验证主链路完整可用）
  运行时 onboarding / 交付体验
  用户自定义场景规则
```

如果要继续推进，请先从 `main` 开一个新的 OpenSpec change，而不是继续修改旧的 archived change。
