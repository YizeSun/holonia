# Holonia 总体实施路线

更新时间：2026-07-21

本文记录 Holonia 的长期阶段路线，不表示所有阶段都已经实现。当前代码
只覆盖 NearBridge 的单设备对实验纵向链路；开放网络、代码任务交付、
支付和信誉仍属于后续工作。

## 当前状态

- Phase 0 的核心概念与 NearBridge 技术实验已经形成可检查文档和证据。
- Phase 1 已从基础发现推进到 NB-9：真实 iPhone 与 Mac 已跑通发现、明确
  配对、fresh-session 认证、签名消息、联系流程和受限 Primary Holon
  model-only 调用。
- Phase 2 的最小联系状态机已经在 NearBridge 内验证，但尚未实现开放传播
  或跨 Principal 联系网络。
- Phase 3 及之后尚未实现。

## 路线原则

- 先验证真实链路，再冻结公共协议。
- 每个阶段必须有一条可演示的端到端用户路径。
- Core 保持通用且小；复杂规则留在专业网络。
- NearBridge 先于开放网络实现。
- 联系型需求必须早于交付、付款和复杂信誉。
- 每个阶段明确非目标，防止宏大愿景同时进入实现。

## Phase 0：文档和技术决策

目标：固定已经达成共识的概念，并完成 NearBridge 技术验证。

产出：

- 当前设计决策文档；
- NearBridge 技术选型实验；
- 第一对目标平台和设备；
- 最小消息模型草案；
- 威胁模型草案；
- 端到端演示标准。

不做：公开协议发布、支付、信誉公式、开放互联网广播。

## Phase 1：NearBridge

目标：在两台 Apple 设备间完成发现、认证、连接、轻量消息交换和一条
Host 控制的能力调用链路。

首选验证路径：

```text
iPhone Holonia App
↔
Mac mini Holonia App / Host
```

当前实现已进一步加入版本化 Holon manifest、capability registry、显式
execution profile、隔离 XPC runner 和 OpenAI model-only adapter。详细状态见
[`nearbridge-plan.md`](nearbridge-plan.md) 与
[`nearbridge/progress.md`](nearbridge/progress.md)。

## Phase 2：最简单的联系型需求

目标：先在本地或测试网络完成第一条“寻找能力”的闭环，再设计开放传播。

```text
用户提出能力寻找
→ Primary Holon 形成公开摘要
→ Host 批准发送
→ 受限范围传播
→ 另一 Holon 返回 Capability Response
→ Origin 接受联系
→ Request Completed
```

这一阶段不包含正式委托、交付、付款和信誉分数。

完成标准：两台真实设备可以完成一次可重复演示，并留下完整事件记录。

## Phase 3：小型代码任务网络原型

目标：完成一项已有公开仓库或最小复现项目中的小型代码修改。

```text
代码任务
→ Capability Response
→ 私密会话
→ 简单 Engagement
→ Patch / Commit 交付
→ 测试或人工验收
→ Completed
```

详细计划见 [`code-network-plan.md`](code-network-plan.md)。

## Phase 4：受控开放网络实验

只有在 Phase 2 和 Phase 3 的本地闭环稳定后进入。

候选内容：

- 临时 Reply Route；
- 端到端加密会话；
- 直连和 Relay fallback；
- Holon 多跳传播；
- 专有传播聚类；
- 基础反垃圾和速率限制。

## Phase 5：真实商业验证

目标不是立刻搭建完整支付系统，而是验证用户是否愿意为小型代码结果付费。

候选方式：

- 先由平台人工撮合与人工结算；
- 固定价格的小型任务；
- 记录报价、接受、交付和验收事件；
- 观察首个有效回应时间、完成率、争议率和用户操作成本。

支付协议、资金托管和自动分账只有在真实交易出现后再设计。

## 暂不进入路线的内容

- 完整采购或招聘流程；
- 医疗、法律等高风险专业网络；
- 企业私有代码的复杂远程执行；
- 通用仲裁体系；
- 区块链或平台代币；
- 复杂信誉数学公式；
- 无限层级分包；
- 多种编程语言 SDK 同时开发；
- 一个协议适配所有行业。
