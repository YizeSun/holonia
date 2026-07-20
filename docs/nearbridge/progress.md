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
| NB-2 | 未开始 | 未运行 | 未运行 | 未运行 | 待补充 |
| NB-3 | 未开始 | 未运行 | 未运行 | 未运行 | 待补充 |
| NB-4 | 未开始 | 未运行 | 未运行 | 未运行 | 待补充 |
| NB-5 | 未开始 | 未运行 | 未运行 | 未运行 | 待补充 |

NB-1 的 Automated 结论只证明模型、策略、诊断行为与构建成立，不证明当前二进制已在真机完成双向发现。
