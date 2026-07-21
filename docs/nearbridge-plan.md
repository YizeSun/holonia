# NearBridge 第一阶段计划

## 1. 第一目标

NearBridge 第一阶段只回答一个问题：

> 两台由用户明确授权的 Apple 设备，能否稳定地发现彼此、确认身份，并交换 Holonia 的轻量消息？

第一目标不是聚合 GPU，也不是立即运行分布式大模型。

### 当前进度（2026-07-21）

- `NB-0` 普通 Wi-Fi 核心真机路径已经完成：iPhone 与 Mac mini 可发现、连接、双向交换 ping/pong，并在手动断开重连后继续通信。
- `Bonjour + Network.framework` 是进入下一阶段的暂定主方案，仍不代表设备已经可信或通过认证。
- `NB-1` 已完成实现、共享单元测试及 macOS/iOS Device SDK 构建；真机双向发现仍明确标记为待验证。
- `NB-2` 已完成实现与自动化验证：Host Keychain 稳定密钥、签名配对 transcript、双端验证码确认、本地可信记录与撤销；真机配对和重启持久性待验证。
- `NB-3` 已完成实现与自动化验证：paired-key sender authentication、fresh-session binding、签名完整性、过期、去重、ping/pong/ack 相关性与清晰状态；真机交换待验证。
- `NB-4` 已完成实现与自动化验证：Request → Capability Response → Contact Accepted → Completed 的签名联系状态机；不调用 Agent 或远程操作。
- `NB-5` 已完成实现与自动化验证：iPhone 可在完成联系流程后调用 Mac Host 明确注册的 deterministic text-summary Agent，并接收签名 typed result；没有任意命令、文件、云或动态工具入口。
- `NB-1 → NB-5` 的最终集成主路径已在真实 iPhone/Mac 上完成；延期环境、生命周期和边界矩阵仍未执行，所以尚不能称为稳定或生产就绪。
- `NB-6` 已完成实现与自动化验证，并在真实 iPhone/Mac 上跑通 Apple NaturalLanguage 核心路径：Mac 选择编译时 allowlisted Primary Holon Implementation，iPhone 通过统一 `HolonAdapter` facade 调用，Mac 返回 signed real-model result；持久化、adapter 切换和边界矩阵待执行。
- `NB-7` 已完成通用平台 contract 的实现与自动化验证：版本化 `HolonManifest`、capability registry 和显式 adapter execution profile；真机尚未运行，隔离 runner 与远程模型不属于本 checkpoint 的已实现结论。
- `NB-8` 已完成独立 app-sandboxed Apple Foundation Models XPC runner、Host 单次并发策略、session 结束后丢弃结果以及有界 XPC contract；共享测试、macOS/iOS 构建和 Mac bundle 嵌入检查通过，签名 entitlement 与跨设备生成结果待真机验证。
- `NB-9` 已完成 OpenAI model-only Primary Holon adapter、Mac Host Keychain 凭据管理、固定 Responses API 请求和独立 network-client XPC runner；共享测试、macOS/iOS 构建和双 XPC bundle 检查通过，并在一个真实 iPhone/Mac 设备对上观察到 signed question → model-only answer → acknowledgement 主路径。错误、重复性和多设备矩阵仍待验证。
- Build Week `P0/P1 Review Readiness` 已完成：默认 Demo 与详细 Diagnostics、五项 readiness、示例问题、signed execution receipt、净化导出、session safety identifier 和评审/提交/eval 文档。54/54 测试和 macOS/iOS Device 构建通过；重组后的 UI、回执和导出待真机观察。它不占用下文预留给第三方 adapter 准入的 `NB-10`。
- 每个 `NB` 都使用独立 Git commit 和远端 checkpoint；自动化、模拟器与真机证据分别记录，后续修复添加新 commit，不改写已测试 checkpoint。
- 不阻塞主线的权限、生命周期、网络环境和候选技术补测记录在 [`nearbridge/deferred-validation-todo.md`](nearbridge/deferred-validation-todo.md)。

## 2. 第一设备组合

建议优先：

```text
iPhone / iOS
↔
Mac mini / macOS
```

原因：它直接覆盖最初的手机能力不足场景。iPad 和 MacBook 在同一基础稳定后加入。

## 3. 最小能力范围

NearBridge v0 只包含：

1. 本地节点发现；
2. 用户确认配对或加入关系；
3. 节点身份认证；
4. 建立双向会话；
5. 发送和接收小型消息；
6. 断线、重连和基本错误反馈；
7. 基础事件日志。

暂不包含：

- 大文件传输；
- 远程 shell；
- 任意文件系统访问；
- GPU 切分或模型并行；
- 公网 NAT 穿透；
- 开放 P2P 多跳；
- 支付和信誉。

## 4. 技术实验顺序

### NB-0：传输与发现实验

比较候选 Apple 技术在真机上的行为：

- UDP broadcast / multicast；
- Bonjour / mDNS；
- Network.framework；
- MultipeerConnectivity；
- 必要时的 TCP、QUIC 或其他可靠会话。

实验需要记录：

- App 前台、后台和锁屏限制；
- iOS Local Network 权限行为；
- Wi-Fi、热点和不同路由器环境；
- 发现延迟；
- 丢包和重连；
- 广播是否能覆盖目标环境。

该实验的目的不是选择最“先进”的技术，而是选择满足第一条用户链路且行为可预测的组合。

### NB-1：节点发现

完成：

```text
iPhone 看到 Mac mini
Mac mini 看到 iPhone
```

发现消息只携带最少信息，不广播私人内容和完整能力清单。

实现状态与验证证据见 [`nearbridge/nb1-results.md`](nearbridge/nb1-results.md)。

### NB-2：配对与身份

- 用户在至少一侧确认配对；
- 双方建立稳定节点身份；
- 防止同一局域网陌生设备自动加入；
- 配对可以撤销；
- 密钥归 Host 管理。

具体身份算法和恢复机制尚未冻结。

当前 checkpoint 的具体实现与安全边界见 [`nearbridge/nb2-results.md`](nearbridge/nb2-results.md)。

### NB-3：可靠消息会话

- 认证后建立双向连接；
- 发送请求、回应和确认；
- 消息具备 ID、发送者、类型、过期时间和完整性验证；
- 重复消息不会重复触发上层动作；
- 连接中断后有明确状态。

当前 checkpoint 的消息保证、非保证和验证证据见 [`nearbridge/nb3-results.md`](nearbridge/nb3-results.md)。

### NB-4：联系型需求演示

在 NearBridge 上实现最简单的 Holonia 闭环：

```text
iPhone：寻找“能够分析这个代码问题的能力”
Mac mini：回应“我有本地代码 Agent，可继续沟通”
iPhone：接受联系
Request：Completed
```

这一阶段先不要求实际运行代码 Agent。目标是验证 Request、Capability Response 和 Contact Accepted 的消息路径。

当前 checkpoint 的状态机、非 Agent 边界和验证证据见 [`nearbridge/nb4-results.md`](nearbridge/nb4-results.md)。

### NB-5：本地能力调用实验

在前四步稳定后，允许 iPhone 通过受控 Host 接口调用 Mac mini 上一个非常窄的能力，例如：

```text
输入一段文本
→ Mac mini 本地模型生成摘要
→ 返回结果
```

该能力必须是明确注册的接口，不开放任意命令执行。

当前 checkpoint 的 Host allowlist、Agent 示例、安全边界和验证证据见 [`nearbridge/nb5-results.md`](nearbridge/nb5-results.md)。

### NB-6：Primary Holon Implementation 与 adapter 实验

NB-5 证明固定 handler 可以通过 Host boundary 被调用。NB-6 进一步验证：

```text
Mac 用户本地选择 Primary Holon Implementation
→ Host 只启用对应编译时 HolonAdapter
→ iPhone 仍只看见稳定、窄化的 text-insight capability
→ 真实设备端模型或 deterministic fallback 在同一授权边界后执行
```

NB-6 不绑定 Primary Holon Account，不允许远端选模型，不开放文件、workspace、shell、网络或动态工具。当前真实模型选项是 Apple `NaturalLanguage` 的设备端 language/sentiment model，不是 LLM。

当前实现、自动化证据、明确非目标和下一条真机步骤见 [`nearbridge/nb6-results.md`](nearbridge/nb6-results.md)。

### NB-7：通用 Holon manifest、registry 与 execution profile

NB-7 把 NB-6 的编译时 adapter 描述升级为可验证的通用 contract：

```text
versioned HolonManifest
→ typed capability schemas and limits
→ duplicate-safe capability registry
→ explicit isolation/network/credential profile
→ Host resolves a capability to one implementation boundary
```

当前允许的 profile 仍非常窄：同进程 inert-text handler、无网络的 app-sandboxed local-model runner，以及未来明确授权的 OpenAI model-only provider。所有当前 profile 都拒绝文件读写、命令执行和动态工具。声明 profile 不等于执行环境已经具备对应强隔离；隔离 runner 必须在后续 checkpoint 由独立进程和 entitlements 实现并验证。

当前实现、自动化证据和非目标见 [`nearbridge/nb7-results.md`](nearbridge/nb7-results.md)。

### 通用平台之后的实施顺序

1. `NB-8`：Host 管理的本地生成模型通过独立 app-sandboxed runner 执行，默认无文件、无命令、无网络。实现与自动化已完成，物理验证待运行。
2. `NB-9`：增加显式网络披露与 Host Keychain API key 的 OpenAI model-only adapter；iPhone 通过现有稳定 inert-text capability 调用并显示 signed typed answer，不使用 Codex App/CLI 登录，也不传 tools。
3. `NB-10`：签名第三方 adapter 的准入、版本兼容和隔离验证。
4. 更晚：只读项目分析与可写/命令型 Codex Agent，按独立安全计划推进。

### NB-8：独立本地生成模型 runner

NB-8 将 `NB-7` 声明的 `sandboxedLocalModel` profile 落到独立 XPC service：

```text
authenticated iPhone invocation
→ Mac Host policy + capability registry
→ bounded XPC request
→ app-sandboxed Apple Foundation Models runner (tools: [])
→ bounded XPC response
→ signed typed NearBridge result
```

Host 同一时间只允许一个模型调用；连接或认证会话在结果返回前结束时，结果会被丢弃。XPC contract 不携带文件路径、workspace、凭据、命令或工具描述。当前 bundle 嵌入和无签名构建已检查，实际签名 entitlement、运行时进程边界和 iPhone → Mac → iPhone 生成结果必须由物理测试补证。

当前实现、自动化证据和物理验证步骤见 [`nearbridge/nb8-results.md`](nearbridge/nb8-results.md)。

### NB-9：OpenAI model-only Primary Holon

NB-9 在相同通用 registry 和稳定 capability facade 后增加远程强模型选项：

```text
iPhone plain-text question
→ authenticated and signed NearBridge invocation
→ Mac Host policy + selected Primary Holon
→ Host Keychain credential loaded for this invocation
→ app-sandboxed network-client XPC
→ fixed OpenAI Responses API model (store: false; tools omitted)
→ bounded inert-text answer
→ signed typed result
→ iPhone display
```

Mac 用户决定是否选择该实现，并只在 Mac App 内配置独立 OpenAI API key。iPhone 不能选择 provider、发送凭据、改变 endpoint/model 或开启工具。API key 只在 Host 与 XPC 的单次内存请求中出现，不进入 NearBridge 消息、HTTP body 或结构化诊断。

这一 checkpoint 所说的 “Codex” 是强 OpenAI 模型的纯文本回答能力，不是 Codex App/CLI 会话或工具型 coding Agent。它没有 workspace、文件、命令、Git、动态 tools、持久记忆或常驻 daemon。真实 API 调用可能产生 OpenAI API 用量与费用，且只有用户配置凭据并主动发问时才会发生。

当前实现、自动化证据和物理验证步骤见 [`nearbridge/nb9-results.md`](nearbridge/nb9-results.md)。

NB-9 当前只允许一个活动 TCP/认证 session 和一个在途模型调用。附近多台设备可以被发现，多个身份可以先后配对并保存在 trust registry，但尚无多客户端并发、排队、负载均衡或自动回答者选择；请求只会发给用户当前连接并认证的 Mac，再由该 Mac 本地选择的 Primary Holon Implementation 回答。

### NB-5 完成后的含义

当 `NB-1` 到 `NB-5` 各自的核心验收条件都满足时，NearBridge v0 的第一条功能纵向链路成立：

```text
发现不可信节点
→ 用户明确配对
→ 认证并建立受保护消息会话
→ 交换联系型 Request / Response
→ 调用一个明确注册的本地能力
→ 返回结果并留下诊断或审计事件
```

这可以称为 **NearBridge v0 feature-complete vertical slice**，但不能直接称为生产就绪。稳定版本仍需要执行延期验证矩阵、重复性与生命周期测试、安全审查、协议迁移策略和发布级体验收尾。

开放 P2P、多跳传播、跨 Principal 信誉、支付和专业网络属于更广泛的 Holonia 路线，不是 NearBridge v0 在 `NB-5` 之后缺失的同一层功能。

## 5. 建议的最小模块边界

在技术实验结束前不冻结完整仓库结构。概念上只保留：

```text
Apple App
NearBridge Discovery
NearBridge Session
Host Security Boundary
Minimal Message Types
```

UDP 负责什么、可靠会话使用什么、是否需要独立 package，应由 NB-0 真机实验结果决定。

## 6. 完成标准

NearBridge 第一阶段完成，需要同时满足：

- iPhone 与 Mac mini 在真实局域网中发现并完成用户授权；
- 陌生设备不能未经授权加入；
- 双方可以稳定交换至少一种 Request 和 Response；
- 重复、过期和格式错误消息被安全处理；
- 用户可以撤销配对；
- 关键操作有可检查日志；
- 核心演示连续重复运行，不依赖手工修改地址或重启服务。

## 7. 第一阶段风险

- iOS 后台网络限制可能改变发现和会话设计；
- UDP 广播不能跨路由器，也可能被部分网络禁用；
- MultipeerConnectivity 的行为和可观察性可能不适合长期协议；
- 本地网络权限提示会影响首次使用体验；
- 设备休眠和 App 生命周期可能导致 Host 不持续在线；
- Mac mini 常驻 Host 和普通 macOS App 可能需要不同实现方式。
