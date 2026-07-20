# NearBridge NB-5 Results

Status: **Implementation and automated checkpoint passed; physical validation pending.**

## Scope

NB-5 把 NB-4 联系演示收窄为 `holonia.capability.text-summary.extractive.v1`，并增加一个真实但确定性的本地能力调用：

```text
iPhone plain-text input (≤ 1,200 characters)
→ signed capabilityInvocation
→ Mac Host checks authenticated session + completed contact workflow + exact registry ID
→ LocalSummaryAgent executes in-process deterministic extractive summary
→ signed capabilityResult (≤ 280 characters)
→ iPhone displays result
```

Mac registry 只有一个编译时明确注册的 handler。远端不能注册新能力、传入命令名、路径、URL、工具参数或进程参数。`LocalSummaryAgent` 只按句子边界取前两句并限制长度；它用于展示 Agent 在架构中的位置，不冒充 LLM。

## Agent example

这个示例里各层职责是：

1. **NearBridge**：发现、配对、sender/session authentication、typed message、expiry、dedup 和诊断。
2. **Holonia Host policy**：检查联系流程完成、设备角色是 Mac、capability ID 在本地 allowlist、输入输出长度符合注册描述。
3. **LocalSummaryAgent**：只收到已经授权的纯文本任务，运行一个本地 handler，返回纯文本结果。
4. **NearBridge result path**：把 typed result 签名后返回 iPhone；失败返回有限、类型化 failure。

未来可把这个 handler 替换为用户选择的 Primary Holon Implementation 或本地模型 adapter，但仍应经过同一个 Host capability boundary。当前 NB-5 **没有 Primary Holon 选择 UI**，也没有账户绑定；现在能选择和看到的是固定注册 capability，而不是 Primary Holon。

## Explicit security boundary

实现没有 `Process`、shell、文件系统、URLSession、云、exo、支付、信誉或开放网络传播。像命令的输入仍是 inert text。未知 capability、空输入、超过 1,200 字符的输入、超过 280 字符的输出、错误 correlation 和未完成联系流程都会失败。

消息仍沿用 NB-3 的签名完整性，但 payload **没有加密**。Agent 在 App 进程内同步执行；没有 daemon 或后台常驻服务。

## Decisions required for this checkpoint

- 使用 deterministic extractive summarizer，保证自动化结果可重复且不引入模型依赖、下载或外部许可。
- 只在 Mac role 注册能力；iPhone role registry 为空。
- 只有 NB-4 contact workflow 为 completed 且 session authenticated 时才允许 invocation。
- 编译时 registry 是远程输入与执行代码之间的唯一分派点。

## Decisions deliberately open

- Primary Holon Account / Implementation 的选择、授权、切换和恢复 UI；
- LLM 或其他 Agent adapter 的沙箱、数据披露、资源预算、取消和审计；
- payload encryption、模型隐私、prompt injection policy 和输出信任标记；
- capability discovery、版本协商、用户逐次授权与长期 schema；
- 后台 Host、跨网络、开放传播、支付和信誉。

## Automated evidence

2026-07-20 执行 `cd NearBridge && swift test`：27 tests passed, 0 failures。

NB-5 新增测试覆盖：

- Mac registry 只包含预期 summary capability；
- deterministic 两句摘要输出；
- 未注册 capability 与 1,201 字符输入拒绝；
- 含 “shell command” 的文字只作为 inert text 进入摘要；
- signed invocation/result 的 invocation ID、message correlation、status 和 signature。

以下构建均 `BUILD SUCCEEDED`：

```text
xcodebuild -project NearBridge/NearBridge.xcodeproj \
  -scheme NearBridgeMac -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/NearBridgeNB5Mac \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild -project NearBridge/NearBridge.xcodeproj \
  -scheme NearBridgeIOS -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/NearBridgeNB5IOS \
  CODE_SIGNING_ALLOWED=NO build
```

iOS 是 Device SDK 构建，不是安装或运行。

## Simulator evidence

**Not run.**

## Physical evidence

**Pending.** 不能从单元测试或 NB-0 的旧 ping/pong 外推。

## Next physical test

1. 从本 NB-5 checkpoint 安装并启动两端，完成 pairing，确认 `Authentication: authenticated`。
2. 按 NB-4 UI 完成 `Request text-summary contact` → Response → Accept → Completed。
3. Mac 确认 registry 只显示 `holonia.capability.text-summary.extractive.v1` 和 `LocalSummaryAgent (deterministic demo)`。
4. iPhone 保留默认三句示例，点 `Invoke registered Mac summarizer`。
5. 确认 Mac 显示 execution succeeded；iPhone 收到只含前两句、≤ 280 字符的 result。
6. 输入一段看起来像命令的普通文本，确认它只被摘要，没有任何系统动作。
7. 输入超过 1,200 字符，确认按钮禁用或调用被拒绝。
8. 保存两端 `capability.executing`、`resultSent`、`succeeded` 和对应 message UUID 截图。

完成这条物理链路后，才能称该设备对上的 NearBridge v0 vertical slice 已被真机观察到；稳定版本仍需要延期验证 TODO、安全审查、payload encryption 决策和重复性测试。
