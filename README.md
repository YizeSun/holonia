# Holonia

Holonia 是一个面向人、Agent 与组织的能力发现和工作连接网络。它让一个主体在自身能力不足时，可以寻找其他能力、建立私密联系，并在适合的专业网络中完成委托、交付与验收。

项目当前处于概念固定与 NearBridge 通用 Primary Holon 平台验证期，尚未冻结公开协议。NearBridge `NB-0` 的普通 Wi-Fi 真机核心路径已经跑通，`NB-1` 到 `NB-5` 的最终集成纵向链路已有真实 iPhone/Mac 证据；`NB-6` 的 Mac Primary Holon Implementation 选择、统一 Holon adapter 和 Apple 设备端 NaturalLanguage model 也已完成自动化、双目标构建和单一设备对上的真机核心路径。`NB-7` 建立带版本的 manifest、capability registry 和 execution profile；`NB-8` 增加嵌入 Mac App、默认无文件/命令/网络接口的 app-sandboxed Apple Foundation Models XPC runner；`NB-9` 增加由 Mac Host 明确选择、以 Keychain 凭据调用固定 OpenAI Responses API 模型的 model-only adapter。NB-9 已在一台真实 iPhone 与一台 Mac 上完成问题、受限模型调用、签名结果显示和 acknowledgement 主路径。Build Week `P0/P1 Review Readiness` 把同一纵向链路整理为评审可读的 Demo/Diagnostics 双视图，加入 readiness、示例问题、签名执行回执、安全诊断导出和 OpenAI safety identifier；它不占用路线图中预留给第三方 adapter 准入的 `NB-10`。同一真实设备对已观察两端 readiness、相关联 execution receipt 和净化导出主路径。错误、重复性、多设备和生命周期矩阵仍未完成，当前不是生产就绪版本。

## OpenAI Build Week 2026

本仓库首个 commit 是 2026-07-17，NearBridge 是在 Build Week 期间为本次活动构建的项目。建议提交赛道为 **Apps for Your Life**：它让 iPhone 用户在同一局域网内明确选择、认证并调用 Mac 上更强但受限的 Primary Holon，然后收到签名、相关联、可审计的答案。

- **GPT-5.6 的实际产品角色**：Mac 上的 `OpenAIModelOnlyHolonAdapter` 通过固定 Responses API 请求回答 iPhone 的纯文本问题；请求 `store: false`、不携带 tools，并受输入/输出上限约束。
- **Codex 的构建角色**：用于需求拆解、Apple 网络与认证实现、SwiftUI、XPC 隔离、安全收敛、测试、真机故障诊断和评审文档。提交时需要在 Devpost 的 `/feedback` 命令中提供对应 Codex Session ID。
- **快速评审**：[Build Week reviewer runbook](docs/build-week/reviewer-runbook.md)
- **英文提交草稿**：[Build Week submission draft](docs/build-week/submission-draft.md)
- **评测与失败矩阵**：[Build Week evaluation plan](docs/build-week/evaluation-plan.md)
- **最后阶段视频 TODO**：[Build Week video production TODO](docs/build-week/video-production-todo.md)

API key 不在仓库中。评审者可以选用 Apple 设备端或 deterministic adapter 观察无 key 路径，也可以在 Mac App 中自行将测试 key 保存到 Keychain，以复现真实 GPT-5.6 路径。

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
- [NearBridge NB-6 Primary Holon checkpoint](docs/nearbridge/nb6-results.md)
- [NearBridge NB-7 通用 Holon contract checkpoint](docs/nearbridge/nb7-results.md)
- [NearBridge NB-8 隔离本地模型 runner checkpoint](docs/nearbridge/nb8-results.md)
- [NearBridge NB-9 OpenAI model-only checkpoint](docs/nearbridge/nb9-results.md)
- [Build Week P0/P1 demo/review readiness checkpoint](docs/nearbridge/build-week-p0-p1-results.md)
- [NearBridge 延期验证 TODO](docs/nearbridge/deferred-validation-todo.md)
- [小型代码任务网络计划](docs/code-network-plan.md)
- [开放问题和后续决策](docs/open-questions.md)

## 当前实施顺序

1. 已完成 NearBridge 的最小跨设备通信、认证、联系与窄能力调用闭环。
2. 建立通用 `HolonManifest`、capability registry 和 adapter execution profile。
3. 把 Host 管理的本地生成模型放入无文件、无命令、默认无网络的隔离 runner；实现和自动化已完成，签名运行时与跨设备结果待真机验证。
4. 增加明确选择、明确凭据和明确网络披露的 model-only OpenAI adapter；实现、测试、构建和单一真实设备对上的跨设备回答主路径已完成，错误与稳定性矩阵待验证。
5. 完成签名第三方 adapter 的准入与隔离协议后，再考虑更强的工具型 Agent。

## 已实现与仍未实现

当前已经实现：局域网发现、用户配对、稳定 Host 身份、fresh-session 认证、签名/过期/去重消息、联系状态机、Host allowlist capability、Primary Holon Implementation 选择，以及真实 Apple 设备端分类模型 adapter。`NB-7` 进一步提供带版本且可验证的 manifest、稳定 capability schema、registry 路由和显式 execution profile；`NB-8` 将 Apple Foundation Models 生成式实现放进嵌入 App 的独立 XPC service；`NB-9` 将固定 OpenAI model-only 实现放进另一个独立 XPC service。OpenAI 凭据只在 Mac App 输入并保存到 Host Keychain；请求固定到 OpenAI Responses API、`store: false`，不发送 tools，也不提供路径、workspace、shell、Git 或设备控制接口。源 entitlement、有界协议和开发签名 XPC entitlement 已检查；真实 OpenAI 回答已在一个 iPhone/Mac 设备对上返回并显示。

已经观察成功的远程模型纵向路径是：

```text
iPhone 输入普通问题
→ authenticated NearBridge request
→ Mac Host policy + capability registry
→ 用户选择的受限 Primary Holon adapter
→ 本地隔离模型或明确授权的 OpenAI model-only API
→ signed typed result
→ iPhone 显示答案
```

当前 discovery 可以同时列出多台附近设备，trust store 也可以保存多个历次配对身份，但实现只允许一个活动 TCP/认证会话和一个在途 Primary Holon 调用。它没有并发多客户端、请求队列、负载均衡或自动选择回答者；iPhone-to-iPhone Primary Holon 工作流也不是当前支持目标。

这里的“Codex”只指 OpenAI 的强模型回答纯文本问题；它不会继承 Codex App/CLI 的登录状态，也不会获得 workspace、文件、shell、Git 或任意 tool access。用户需要在 Mac App 内单独配置 API key，凭据只由 Host Keychain 管理。

以下能力明确尚未实现，并保存在 TODO：让 Codex 读取项目并分析，需要受控的 workspace selector、只读文件 broker、上下文预算和逐次授权；让 Codex 自主修改代码、运行命令或长期工作，还需要命令/写入策略、隔离、审批、取消、资源预算、崩溃恢复和审计。它们不会借由“第三方模型本身可能有沙箱”而自动获得授权。
