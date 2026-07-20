# Holonia 愿景、术语和已确定设计

本文只记录讨论中已经明确同意的方向。尚未确定的实现方式放在 `open-questions.md`，避免把候选方案误写成既定架构。

## 1. 愿景

Holonia 试图解决同一个根问题：

> 当一个人或 Agent 的当前能力不足时，如何找到更合适的能力，把工作委托出去，并得到可确认的结果。

它最初来自两个场景：

1. 手机上的小模型能力有限，希望调用 Mac、本地大模型、云端模型或多个能力来增强手机。
2. 不熟悉 GPT、Codex 或代码的用户，希望通过自己的代理找到能够解决问题的 Agent、高手或组织。

二者共享“需求—能力发现—回应—交付”的语义，但处于不同信任范围：

- **本地能力范围**：同一用户拥有或明确授权的设备、模型、工具和 Agent。
- **开放能力范围**：不同个人或组织所代表的 Holon。

Holonia 是一个共同愿景，但工程上允许本地能力和开放网络使用不同的发现、信任、结算和传输机制。

## 2. 核心原则

### 2.1 Holon 提议，Host 执行，人类授权

> **Holon proposes. Host enforces. Human authorizes.**

- Primary Holon 理解需求、选择候选方案并提交 Proposal。
- Holonia Host 独占身份密钥、系统权限、网络发送、数据访问、审计和支付执行权。
- Primary Holon 不能绕过 Host 直接执行高权限操作。
- 跨越信任域、披露新敏感信息、形成正式承诺或付款时，由人类作关键授权。

Host 能约束未授权行为，但不能保证 Holon 的建议一定正确，也不能保证外部交付一定安全或高质量。

### 2.2 Primary Holon 可由第三方替换

- 官方实现用于项目早期。
- 未来允许第三方提供更好的 Primary Holon Implementation。
- 一个 Primary Holon Account 同一时刻只有一个当前主要实现。
- 更换实现不改变账户、身份、信誉、共享域关系和任务历史。
- 第三方实现通过受控接口提出行动，不直接持有用户身份密钥和网络权限。

### 2.3 一账户一全局稳定身份

- 一个 Primary Holon Account 只有一个全局稳定 Holon Identity。
- 需要更多身份时，必须显式创建更多 Primary Holon Account。
- Principal、账户和实现不是同一个概念：

```text
Principal
└── Primary Holon Account（稳定身份、信誉、关系、历史）
    └── Primary Holon Implementation（可替换的软件）
```

- 临时 Reply Route、网络地址和会话地址不是新身份。
- 一个 Principal 可以拥有个人、工作或组织用途的不同账户，但各账户的身份和信誉相互独立。

## 3. 共享信任域

共享信任域允许多个 Principal 在明确规则下共享资源或能力，但不会合并其身份或设备所有权。

### 3.1 治理

- 只有共享域创建者拥有解散共享域的权利。
- 创建者可以根据域规则授予管理员权限。
- 管理员可以根据授权管理成员和规则，但不能解散共享域。
- 创建者或管理员可以移除其他共享者；移除成员时，其设备、资源和域内凭证同时退出。
- 资源所有者可以主动撤销自己的资源，也可以主动退出共享域。

### 3.2 Policy、Grant 和 Enforcement

Holonia 不固定定义“共享什么”，而是提供规则机制：

```text
有效权限
  = Domain Policy
  ∩ Owner Grant
  ∩ Host Safety Policy
```

- **Domain Policy**：创建者或管理员定义共享域规则。
- **Owner Grant**：资源所有者决定自己提供什么以及提供到什么范围。
- **Host Enforcement**：资源所在设备的 Host 执行最终权限判断。

Holonia Core 不把 `read/write/run` 写死成适用于一切资源的权限。专业网络、共享域模板或资源提供方可以定义自己的 Resource 与 Action。

## 4. 需求和传播

### 4.1 Work Request 而不是 Prompt

Holonia 的基本单位是广义 Work Request。Prompt 只是它的一种输入形式。需求可以是寻找能力、寻找联系人，也可以是要求得到可验收的数字交付物。

### 4.2 Primary Holon 可提出任意传播范围

Holonia 不规定必须按照“当前设备—个人设备—家庭域—公网”的顺序寻找能力。

- Primary Holon 可以直接提出任意传播范围或多个范围。
- Host 检查权限、Domain Policy、数据披露和预算。
- 用户批准关键传播行为。

候选传播范围包括本地节点、个人域、共享域、外部服务、指定 Holon、专有聚类和开放网络。

### 4.3 需求可以多跳传播

- 一跳按照 Holon 计算，而不是按照设备、IP 路由器或传输连接计算。
- 发布者可以指定最大 Holon 跳数。
- 发布者可以指定公开范围或专有传播聚类。
- 中间 Holon 可以选择 Respond、Forward、Both 或 Ignore。
- 最大跳数是合规 Holonia 节点遵循的传播上限，不是防止信息被恶意复制的 DRM。

### 4.4 不可修改内容和追加式传播记录

传播消息在概念上分为：

1. 发布者签署的不可修改 Origin Envelope；
2. 发布者签署的不可修改 Payload 或其摘要；
3. 每次 Holon 转发时追加的可验证 Relay Record。

Origin Envelope 至少需要表达消息身份、Origin、需求类型、传播范围、最大跳数、过期时间和 Payload 完整性。具体编码尚未确定。

消息去重、过期、跳数和转发决策属于 Holonia Propagation Layer，不交给 Primary Holon逐条处理，也不等同于 IP TTL。

### 4.5 聚类和信任域不同

- **Trust Domain** 决定身份关系、授权和资源共享。
- **Propagation Cluster** 决定某类需求向哪些 Holon传播。

同一 Holon 可以加入多个传播聚类；处于同一聚类不代表彼此可信。

## 5. Capability Response 与回复路径

### 5.1 初步回应不是正式承诺

Capability Response 的最低语义是：

> 我可能具备相关能力，并愿意进一步沟通。

最低内容包括回应者、相关能力说明、沟通意愿和回复方式。能力证明、历史交付、初步条件、价格范围和问题是可选信息。

### 5.2 临时 Reply Route

开放网络默认使用短期、受限、与单个 Request 关联的 Reply Route 接收轻量回应：

- 不直接暴露永久网络地址；
- 限制有效期、消息大小、频率和用途；
- Capability Response 由稳定 Holon Identity 签名；
- 用户接受联系后，双方优先建立直接端到端加密会话；
- 无法直连时使用端到端加密 Relay；
- 沿原传播路径返回只作为可选方案，不作为唯一机制。

NearBridge 内已认证的本地连接可以直接返回。

## 6. 私密会话

私密会话采用范围授权，而不是每条消息都要求用户批准，也不是首次批准后完全放任。

- 用户批准 Session Grant。
- Primary Holon 在授权范围内可以自主进行多轮沟通。
- Host 检查外发信息和动作是否越界。
- 披露新敏感数据、上传文件、形成正式承诺、接受价格和付款时重新请求用户确认。
- 用户可以查看、暂停、接管、恢复或关闭会话。
- 关键消息、授权变化和披露行为保留审计记录。
- 私密会话不等于正式委托。

## 7. 两种基础需求流程

### 7.1 联系型需求

联系型需求的目标是完成有效信息匹配，不要求 Holonia 承担后续行业流程。

```text
Request
→ Capability Response
→ 需求方确认有效联系
→ Completed
```

采购寻找供应商、公司寻找求职者、用户寻找专家都可以在有效联系处结束。后续采购、招聘或合同继续由专业系统处理。

### 7.2 交付型需求

```text
Request
→ Capability Response
→ Private Session / Negotiation
→ Engagement Offer（需求方发起）
→ Engagement Accepted（执行方接受，正式委托成立）
→ Delivery
→ Acceptance
→ Completed
```

- 接受前的回应、沟通和初步报价不是正式承诺。
- 正式委托由需求方发起，在执行方接受时成立。
- 已成立版本不能被单方面修改；修改需要双方重新确认。

## 8. Acceptance Policy

Holonia 提供可扩展的验收机制，但不替双方定义“什么是好结果”。

正式委托的最小核心是：

```text
Deliverable Specification
Acceptance Policy
Reviewer
Signed Version
```

可选约束包括期限、预算、修改次数和里程碑。

验收可以是需求方确认、清单、自动验证、第三方验收或组合方式。逐条验证不是所有任务的强制形式；强制要求的是双方在委托成立前明确怎样才算完成。

## 9. 分包

Holonia 的长期设计允许分包：

- 同一 Holon 内部调用自己的模型、工具、设备或 Agent 不算外部分包。
- 跨 Principal 的外部分包形成独立子委托。
- 主执行方始终对上游交付负责。
- 子执行方只获得完成子任务所需的最少信息。
- 传播跳数和分包深度是不同概念。
- 具体分包透明度、审批和行业约束应由双方条款或专业网络定义，而不进入通用 Core 的固定枚举。

## 10. 信誉

信誉至少是双向和角色相关的：

- **Publishing Reputation**：需求发布行为的信誉。
- **Responding Reputation**：回应和执行行为的信誉。

信誉低时应限制对应行为，例如发布频率、传播范围、回应频率或同时接受任务数量，而不是简单封禁整个身份。

现阶段不确定数学公式。底层应保存可验证的事实事件，评分是可替换、带版本的派生结果。事实、主观评价和争议结论不能混为同一种记录。

## 11. Core 与专业网络的边界

Holonia 不试图让一个通用网络处理采购、招聘、软件开发、计算、医疗等全部规则。

### Holonia Core 倾向只负责

1. 稳定 Holon Identity；
2. 签名消息；
3. 需求公告；
4. 范围、聚类、跳数、去重和过期传播；
5. Capability Response；
6. 临时 Reply Route；
7. 私密会话；
8. 可选的通用 Offer、Accept、Delivery、Acceptance 和 Close 消息。

### Specialized Network 负责

- 行业需求格式；
- 匹配规则；
- 专业信誉算法；
- 验收模板；
- 付款方式；
- 分包和争议规则；
- 行业资质与合规。

第一个专业网络收窄为：**面向已有代码仓库的小型、可验证代码任务网络**。

## 12. NearBridge 的定位

NearBridge 是 Holonia 在 Apple 设备上的本地基础：

- 发现附近或同一授权范围内的设备节点；
- 建立认证连接；
- 交换轻量 Holonia 消息；
- 为同一 Primary Holon 或共享域暴露本地能力；
- 为后续本地模型调用和跨设备执行提供基础。

NearBridge 不等于完整 Holonia Protocol，也不承担开放网络的全部 P2P 路由、信誉、付款或行业规则。
