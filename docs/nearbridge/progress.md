# NearBridge 阶段验证状态

更新时间：2026-07-20

## 记录规则

- **Automated**：共享单元测试和目标构建在本地开发环境实际运行。
- **Simulator**：只有实际启动并观察行为才算；仅编译不算模拟器运行。
- **Physical**：必须由真实 iPhone 与 Mac 的运行证据支持。
- 每个阶段使用独立 Git commit；测试后的修复用后续 commit 保留证据链。

## Checkpoints

| 阶段 | 实现 | Automated | Simulator | Physical | 证据 |
| --- | --- | --- | --- | --- | --- |
| NB-0 | 完成 | 通过 | 未运行 | 普通 Wi-Fi 核心路径通过 | [`nb0-results.md`](nb0-results.md) |
| NB-1 | 完成 | 11/11 测试通过；macOS 与通用 iOS 真机构建通过 | 未运行 | 待验证 | [`nb1-results.md`](nb1-results.md) |
| NB-2 | 完成 | 16/16 测试通过；macOS 与通用 iOS 真机构建通过 | 未运行 | 待验证 | [`nb2-results.md`](nb2-results.md) |
| NB-3 | 完成 | 20/20 测试通过；macOS 与通用 iOS 真机构建通过 | 未运行 | 待验证 | [`nb3-results.md`](nb3-results.md) |
| NB-4 | 完成 | 23/23 测试通过；macOS 与通用 iOS 真机构建通过 | 未运行 | 待验证 | [`nb4-results.md`](nb4-results.md) |
| NB-5 | 完成 | 27/27 测试通过；macOS 与通用 iOS 真机构建通过 | 未运行 | 待验证 | [`nb5-results.md`](nb5-results.md) |

NB-1 的 Automated 结论只证明模型、策略、诊断行为与构建成立，不证明当前二进制已在真机完成双向发现。

NB-2 的 Automated 结论只证明密码学消息、确认策略、撤销模型与构建成立，不证明 Keychain、双端 UI 或网络握手已在真机完成。

NB-3 的 Automated 结论证明 signed-message codec 和校验策略，不证明网络上的两端 session 已实际交换新协议消息，也不代表 payload 已加密。

NB-4 的 Automated 结论证明有序联系状态机与消息相关性，不证明两端 UI 已在真机完成整条流程；本阶段没有 Agent 调用。

NB-5 的 Automated 结论证明唯一注册的 deterministic summary Agent、输入/输出边界、未知能力拒绝和 typed signed result；不证明真机网络调用已发生，也不代表已集成 LLM、exo 或 Primary Holon 选择。
