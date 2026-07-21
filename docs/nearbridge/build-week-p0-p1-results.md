# Build Week P0/P1 Review Readiness 结果

更新时间：2026-07-21

## Checkpoint 目标

Build Week P0/P1 不扩展 NearBridge 的网络或 Agent 权限，也不占用路线图中已预留给第三方 adapter 准入的 NB-10。它把已经完成的 NB-9 纵向能力整理为评审者能快速理解、执行和核验的 Demo/Diagnostics 双视图，并补上明确的 readiness、可重试错误、示例问题、执行回执和净化诊断导出。

## 已实现

- `Demo` 与 `Diagnostics` 顶部分段视图；默认不再把几百条日志和所有底层控件堆在主流程中。
- 五项评审 readiness：发现、认证 session、Primary Holon contact、Host implementation、signed answer。
- iPhone 三个非敏感示例问题、输入限制提示，以及失败后的同问题 Retry。
- 跨端执行回执：invocation ID、capability、provider disclosure、peer fingerprint、outcome、完整性语义、acknowledgement、端到端耗时。
- Mac Host provider disclosure 通过已签名的 contact response 到达 iPhone。
- Diagnostics 中的系统 Share 导出；不导出 prompt/answer，只导出 readiness、回执和最近结构化事件，并净化 bearer、Authorization 和 key-like 字符串。
- OpenAI Responses 请求新增由 fresh authenticated session 派生的隐私保护 `safety_identifier`；不发送原始 session ID 或身份信息。
- Build Week reviewer runbook、submission draft、evaluation plan 和延期视频生产清单。

## 自动化结果

- `54/54` Swift 共享单元测试通过。
- 新增覆盖：readiness 排序与完成度、execution receipt、诊断净化、safety identifier 稳定/有界/不暴露 session、OpenAI request body 包含 safety identifier。
- `NearBridgeMac` 使用 macOS arm64 destination 无签名构建成功；产物内嵌 `NearBridgeModelRunner.xpc` 与 `NearBridgeOpenAIRunner.xpc`。
- `NearBridgeIOS` 使用 generic iOS Device destination 无签名构建成功；bundle identifier 为 `org.holonia.nearbridge.nb0.ios`。

## 物理状态

- NB-9 的真实 iPhone → Mac → OpenAI → signed result → iPhone acknowledgement 主路径此前已经观察成功。
- P0/P1 重组后的 Demo UI、执行回执和诊断导出尚未在物理 iPhone/Mac 上观察。本文件在完成新真机步骤前不把它们标为物理通过。

## 下一物理测试

按 [`../build-week/reviewer-runbook.md`](../build-week/reviewer-runbook.md) 从 P0/P1 commit 构建两端，完成一次真实 OpenAI Sample 1 调用；保存两端 Demo 回执截图和一份 sanitized diagnostics 导出，确认其中无 prompt、answer、API key 或 Authorization 值。
