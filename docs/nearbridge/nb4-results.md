# NearBridge NB-4 Results

Status: **Implementation and automated checkpoint passed; physical validation pending.**

## Scope

NB-4 在 NB-3 signed session 上增加一条最小联系型 Holonia 流程：

```text
Request: “Find a local capability that can discuss a small code problem”
→ Capability Response: “A local code-analysis contact is available”
→ Contact Accepted
→ Completed
```

每个步骤都有 workflow request/response UUID、capability identifier、前一步 message correlation、30 秒 expiry、sender/session binding 和 signature。每个业务消息另外收到 signed acknowledgement。

请求方与提供方分别维护方向相关的状态，因此：提供方不能在收到 Request 前发送 Response；请求方不能在收到 Response 前 Accept；只有收到 Acceptance 的提供方能发送 Completed。错误顺序、ID 或 correlation 不推进状态。

## Explicit non-Agent boundary

NB-4 只交换和显示有限长度的结构化文本与标识符。它没有：

- 调用模型、Agent、工具或 exo；
- 读取或修改代码仓库；
- 接受 shell、路径、URL、文件或任意命令；
- 广播完整能力清单；
- 产生支付、信誉或开放网络传播。

UI 明确写出 “No Agent has been invoked”。真实窄能力只从 NB-5 开始。

## Decisions required for this checkpoint

- 固定一个 demo capability ID：`holonia.contact.code-analysis.v1`；它只是联系声明，不是可执行接口。
- 所有用户动作均显式点击，不自动接受联系或完成请求。
- 联系状态只保存在当前 authenticated session；断开时清除，暂不做离线持久化。
- workflow summary 最多 500 字符，capability ID 最多 128 字符。

## Decisions deliberately open

- 通用 Holonia Request/Offer/Accept/Delivery schema 与长期命名空间；
- workflow persistence、重试、取消、拒绝、多个响应和冲突合并；
- Primary Holon 如何代表用户自动回应以及需要什么授权；
- 能力搜索、开放传播、信誉、支付和专业网络 Profile。

## Automated evidence

2026-07-20 执行 `cd NearBridge && swift test`：23 tests passed, 0 failures。

NB-4 新增测试覆盖：

- 两个独立状态机完整执行 Request → Response → Accepted → Completed；
- 两端 request/response ID 和 capability 保持一致；
- 提供方不能跳过 Request 直接 Response；
- 错 correlation 不推进请求方状态。

以下构建均 `BUILD SUCCEEDED`：

```text
xcodebuild -project NearBridge/NearBridge.xcodeproj \
  -scheme NearBridgeMac -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/NearBridgeNB4Mac \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild -project NearBridge/NearBridge.xcodeproj \
  -scheme NearBridgeIOS -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/NearBridgeNB4IOS \
  CODE_SIGNING_ALLOWED=NO build
```

iOS 是 Device SDK 构建，不是安装或运行。

## Simulator evidence

**Not run.**

## Physical evidence

**Pending.**

## Next physical test

1. 在两端完成配对并达到 `Authentication: authenticated`。
2. iPhone 点 `Request code-analysis contact`；确认 Mac 进入 `requestReceived`。
3. Mac 点 `Respond: capability available`；确认 iPhone 进入 `responseReceived`。
4. iPhone 点 `Accept contact`；确认 Mac 进入 `acceptanceReceived`。
5. Mac 点 `Mark contact completed`；确认双方显示 `completed`。
6. 检查两端诊断中的 `workflow` 与 message UUID；确认 UI 没有输入命令、选择文件或运行 Agent 的入口。
7. Disconnect 后确认 session-scoped workflow 回到 idle，并把这一行为记录为预期而不是持久交付保证。

该真机测试通过后只能证明 NB-4 联系消息纵向链路；不能据此宣称 Agent 或能力执行已经发生。
