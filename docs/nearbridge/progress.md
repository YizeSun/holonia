# NearBridge 阶段验证状态

更新时间：2026-07-21

## 记录规则

- **Automated**：共享单元测试和目标构建在本地开发环境实际运行。
- **Simulator**：只有实际启动并观察行为才算；仅编译不算模拟器运行。
- **Physical**：必须由真实 iPhone 与 Mac 的运行证据支持。
- 每个阶段使用独立 Git commit；测试后的修复用后续 commit 保留证据链。

## Checkpoints

| 阶段 | 实现 | Automated | Simulator | Physical | 证据 |
| --- | --- | --- | --- | --- | --- |
| NB-0 | 完成 | 通过 | 未运行 | 普通 Wi-Fi 核心路径通过 | [`nb0-results.md`](nb0-results.md) |
| NB-1 | 完成 | 11/11 测试通过；macOS 与通用 iOS Device SDK 构建通过 | 未运行 | 集成版双向发现主路径通过；专项矩阵待验证 | [`nb1-results.md`](nb1-results.md) |
| NB-2 | 完成 | 16/16 测试通过；macOS 与通用 iOS Device SDK 构建通过 | 未运行 | 集成版配对/认证主路径通过；重启/撤销待验证 | [`nb2-results.md`](nb2-results.md) |
| NB-3 | 完成 | 20/20 测试通过；macOS 与通用 iOS Device SDK 构建通过 | 未运行 | 集成版签名消息通过；专用双向 ping/disconnect 待验证 | [`nb3-results.md`](nb3-results.md) |
| NB-4 | 完成 | 23/23 测试通过；macOS 与通用 iOS Device SDK 构建通过 | 未运行 | 集成版 Contact 主路径通过 | [`nb4-results.md`](nb4-results.md) |
| NB-5 | 完成 | 27/27 测试通过；macOS 与通用 iOS Device SDK 构建通过 | 未运行 | 集成版 Agent 主路径通过；边界矩阵待验证 | [`nb5-results.md`](nb5-results.md) |
| NB-6 | 完成 | 32/32 测试通过；Apple NaturalLanguage adapter 在开发 Mac 上执行；macOS 与通用 iOS Device SDK 构建通过 | 未运行 | Apple real-model 核心路径通过；持久化/切换/边界矩阵待验证 | [`nb6-results.md`](nb6-results.md) |
| NB-7 | 实现完成 | 37/37 测试通过；macOS 与通用 iOS Device SDK 构建通过 | 未运行 | 未运行 | [`nb7-results.md`](nb7-results.md) |
| NB-8 | 实现完成 | 39/39 测试通过；macOS 与通用 iOS Device SDK 构建通过；Mac bundle XPC 嵌入检查通过 | 未运行 | 未运行 | [`nb8-results.md`](nb8-results.md) |

2026-07-21 的集成真机结果记录在 [`physical-validation-2026-07-21.md`](physical-validation-2026-07-21.md)。它基于 `68ee156` 的实现和随后由 `2c76865` 固化的 Mac Apple development signing 配置；它不是五个历史 checkpoint 的逐一安装测试。

NB-1 的 Automated 结论只证明模型、策略、诊断行为与构建成立；集成版已观察双向发现，但 peer-lost/restart/dedup 专项矩阵仍待验证。

NB-2 的集成真机主路径已观察六位码、双端确认、Keychain 写入、paired record 和 authenticated session；重启持久化、撤销及重新配对仍待验证。

NB-3 的集成真机主路径已观察 signed Contact/capability messages 与 acknowledgement；专用双向 signed ping/pong、disconnect/reconnect 尚未运行，payload 仍未加密。

NB-4 的集成真机主路径已在两端 UI 完成完整 Contact 流程；断开连接后的 reset 行为仍待验证。

NB-5 的集成真机主路径已观察 iPhone 调用、Mac 本地 deterministic summary Agent 执行、signed result 返回和预期摘要显示；命令样文本、超长输入和失败路径仍待验证，也不代表已集成 LLM、exo 或 Primary Holon 选择。

NB-6 已在真实 iPhone/Mac 上观察到 Mac 选择 Apple NaturalLanguage Primary Holon、双端完成 Contact、iPhone 发起固定 text-insight invocation、Mac real-model adapter 执行、signed result/ack 返回以及双端相同结果。选择持久化、adapter 切换、失败和稳定性矩阵仍待验证。

NB-7 只建立通用平台 contract：版本化 `HolonManifest`、capability registry 和显式 adapter execution profile。自动化和构建通过不代表隔离 runner、第三方 adapter 或 OpenAI/Codex 远程回答已经完成，也没有 NB-7 真机结果。

NB-8 已把 Apple Foundation Models adapter 放入嵌入 Mac App 的独立 XPC service，并通过源 entitlement、协议边界、超时、单一在途调用与 session 失效丢弃策略限制执行。39/39 测试、两目标无签名构建和产物嵌入检查通过；这些证据不能替代签名后的 entitlement 检查、运行时进程观察或真实 iPhone 发起的生成结果。
