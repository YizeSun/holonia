# Holonia

Holonia 是一个面向人、Agent 与组织的能力发现和工作连接网络。它让一个主体在自身能力不足时，可以寻找其他能力、建立私密联系，并在适合的专业网络中完成委托、交付与验收。

项目当前处于概念固定与 NearBridge 通用 Primary Holon 平台验证期，尚未冻结公开协议。NearBridge `NB-0` 的普通 Wi-Fi 真机核心路径已经跑通，`NB-1` 到 `NB-5` 的最终集成纵向链路已有真实 iPhone/Mac 证据；`NB-6` 的 Mac Primary Holon Implementation 选择、统一 Holon adapter 和 Apple 设备端 NaturalLanguage model 也已完成自动化、双目标构建和单一设备对上的真机核心路径。`NB-7` 建立带版本的 manifest、capability registry 和 execution profile；`NB-8` 增加嵌入 Mac App、默认无文件/命令/网络接口的 app-sandboxed Apple Foundation Models XPC runner；`NB-9` 增加由 Mac Host 明确选择、以 Keychain 凭据调用固定 OpenAI Responses API 模型的 model-only adapter。NB-7 至 NB-9 的自动化与构建状态单独记录，不外推为签名运行时、真实 OpenAI 调用或真机结果。延期边界与稳定性矩阵仍未完成，当前不是生产就绪版本。

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
- [NearBridge 延期验证 TODO](docs/nearbridge/deferred-validation-todo.md)
- [小型代码任务网络计划](docs/code-network-plan.md)
- [开放问题和后续决策](docs/open-questions.md)

## 当前实施顺序

1. 已完成 NearBridge 的最小跨设备通信、认证、联系与窄能力调用闭环。
2. 建立通用 `HolonManifest`、capability registry 和 adapter execution profile。
3. 把 Host 管理的本地生成模型放入无文件、无命令、默认无网络的隔离 runner；实现和自动化已完成，签名运行时与跨设备结果待真机验证。
4. 增加明确选择、明确凭据和明确网络披露的 model-only OpenAI adapter；实现、测试和构建已完成，真实 API 与跨设备结果待用户在 Mac 配置 API key 后验证。
5. 完成签名第三方 adapter 的准入与隔离协议后，再考虑更强的工具型 Agent。

## 已实现与仍未实现

当前已经实现：局域网发现、用户配对、稳定 Host 身份、fresh-session 认证、签名/过期/去重消息、联系状态机、Host allowlist capability、Primary Holon Implementation 选择，以及真实 Apple 设备端分类模型 adapter。`NB-7` 进一步提供带版本且可验证的 manifest、稳定 capability schema、registry 路由和显式 execution profile；`NB-8` 将 Apple Foundation Models 生成式实现放进嵌入 App 的独立 XPC service；`NB-9` 将固定 OpenAI model-only 实现放进另一个独立 XPC service。OpenAI 凭据只在 Mac App 输入并保存到 Host Keychain；请求固定到 OpenAI Responses API、`store: false`，不发送 tools，也不提供路径、workspace、shell、Git 或设备控制接口。源 entitlement 和有界协议已经检查；签名 entitlement、真实 API 回答和跨设备显示仍需物理验证。

正在实现的下一条纵向路径是：

```text
iPhone 输入普通问题
→ authenticated NearBridge request
→ Mac Host policy + capability registry
→ 用户选择的受限 Primary Holon adapter
→ 本地隔离模型或明确授权的 OpenAI model-only API
→ signed typed result
→ iPhone 显示答案
```

这里的“Codex”只指 OpenAI 的强模型回答纯文本问题；它不会继承 Codex App/CLI 的登录状态，也不会获得 workspace、文件、shell、Git 或任意 tool access。用户需要在 Mac App 内单独配置 API key，凭据只由 Host Keychain 管理。

以下能力明确尚未实现，并保存在 TODO：让 Codex 读取项目并分析，需要受控的 workspace selector、只读文件 broker、上下文预算和逐次授权；让 Codex 自主修改代码、运行命令或长期工作，还需要命令/写入策略、隔离、审批、取消、资源预算、崩溃恢复和审计。它们不会借由“第三方模型本身可能有沙箱”而自动获得授权。
