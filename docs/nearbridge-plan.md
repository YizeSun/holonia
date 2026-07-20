# NearBridge 第一阶段计划

## 1. 第一目标

NearBridge 第一阶段只回答一个问题：

> 两台由用户明确授权的 Apple 设备，能否稳定地发现彼此、确认身份，并交换 Holonia 的轻量消息？

第一目标不是聚合 GPU，也不是立即运行分布式大模型。

### 当前进度（2026-07-20）

- `NB-0` 普通 Wi-Fi 核心真机路径已经完成：iPhone 与 Mac mini 可发现、连接、双向交换 ping/pong，并在手动断开重连后继续通信。
- `Bonjour + Network.framework` 是进入下一阶段的暂定主方案，仍不代表设备已经可信或通过认证。
- `NB-1` 已完成实现、共享单元测试及 macOS/iOS Device SDK 构建；真机双向发现仍明确标记为待验证。
- `NB-2` 已完成实现与自动化验证：Host Keychain 稳定密钥、签名配对 transcript、双端验证码确认、本地可信记录与撤销；真机配对和重启持久性待验证。
- 当前主线位于 `NB-2 → NB-3` 的边界，目标是连续推进到 `NB-5`。
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

### NB-4：联系型需求演示

在 NearBridge 上实现最简单的 Holonia 闭环：

```text
iPhone：寻找“能够分析这个代码问题的能力”
Mac mini：回应“我有本地代码 Agent，可继续沟通”
iPhone：接受联系
Request：Completed
```

这一阶段先不要求实际运行代码 Agent。目标是验证 Request、Capability Response 和 Contact Accepted 的消息路径。

### NB-5：本地能力调用实验

在前四步稳定后，允许 iPhone 通过受控 Host 接口调用 Mac mini 上一个非常窄的能力，例如：

```text
输入一段文本
→ Mac mini 本地模型生成摘要
→ 返回结果
```

该能力必须是明确注册的接口，不开放任意命令执行。

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
