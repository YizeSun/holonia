# Holonia

Holonia 是一个面向人、Agent 与组织的能力发现和工作连接网络。它让一个主体在自身能力不足时，可以寻找其他能力、建立私密联系，并在适合的专业网络中完成委托、交付与验收。

项目当前处于概念固定与 NearBridge 第一阶段实现期，尚未冻结公开协议。NearBridge `NB-0` 的普通 Wi-Fi 真机核心路径已经跑通；`NB-1` 与 `NB-2` 的实现和自动化验证已经完成，各自的真机验证等待独立执行。

## 已确定的命名关系

- **Holonia**：整体生态、平台与主项目。
- **Holon**：Holonia 网络中可寻址、可行动、可回应和可交付的代理主体。
- **Primary Holon Account**：一个全局稳定 Holon 身份及其信誉、关系和历史。
- **Primary Holon Implementation**：当前为账户服务的官方或第三方本地代理实现。
- **Holonia Host**：掌握权限、身份密钥、网络、审计和高风险操作执行权的可信宿主。
- **NearBridge**：Apple 设备之间的本地发现、连接与能力访问基础。
- **Holonia Core**：跨专业网络复用的最小身份、传播、回应与私密会话机制。
- **Specialized Network**：建立在 Core 之上的代码、采购、招聘、计算等专业网络。

## 文档

- [愿景、术语和已确定设计](docs/design-decisions.md)
- [总体实施路线](docs/roadmap.md)
- [NearBridge 第一阶段计划](docs/nearbridge-plan.md)
- [NearBridge 阶段验证状态](docs/nearbridge/progress.md)
- [NearBridge 延期验证 TODO](docs/nearbridge/deferred-validation-todo.md)
- [小型代码任务网络计划](docs/code-network-plan.md)
- [开放问题和后续决策](docs/open-questions.md)

## 当前实施顺序

1. 完成 NearBridge 的最小跨设备通信闭环。
2. 在 NearBridge 上跑通最简单的联系型需求。
3. 收窄并验证“已有代码仓库中的小型、可验证任务”。
4. 在真实使用反馈出现后，再决定开放网络、信誉公式、支付和更复杂的专业网络。
