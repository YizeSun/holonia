# NearBridge NB-6 Results

Status: **Implementation and automated checkpoint complete; the core physical Apple NaturalLanguage path passed on one Mac/iPhone pair; deferred boundary and stability tests remain open.**

## Scope

NB-6 在 NB-5 的 Host capability boundary 之上增加一个最小、可逆的 Primary Holon Implementation 层：

```text
Mac user selects a compiled-in Primary Holon implementation
→ selection is stored as a non-secret local preference
→ one HolonAdapter exposes one stable text-insight capability
→ authenticated + approved iPhone sends inert text (≤ 1,200 characters)
→ Mac Host resolves only the selected allowlisted adapter
→ adapter returns inert text (≤ 280 characters)
→ Host signs the typed result and sends it to the iPhone
```

Mac 端有两个编译时实现：

1. `AppleNaturalLanguageHolonAdapter`：默认选项，调用 Apple `NaturalLanguage` 的设备端语言识别和 sentiment model；不发云请求。
2. `DeterministicDemoHolonAdapter`：不使用模型的可重复摘要 fallback，用于验证 adapter 可替换性。

两者只实现同一个固定 facade：`holonia.capability.primary-holon.text-insight.v1`。远端不能提交 adapter 名称、模型路径、文件路径、URL、命令、工具或进程参数。

## Where Primary Holon is selected

Primary Holon Implementation 由 **Mac Host 本地用户**在 `Primary Holon implementation` 区域选择。iPhone 不能替 Mac 选择实现。

选择通过 `UserDefaults` 持久化，因为它只是非敏感偏好；身份私钥和配对记录仍由 Keychain/Host 管理。连接或认证会话活动期间 Picker 被锁定，必须先断开连接再切换，避免联系协商后执行实现发生变化。

这不是 `Primary Holon Account` 选择或账户绑定。NB-6 选择的是当前 Mac App 内的实现 adapter，不创建全局 Holon identity、信誉、关系或历史。

## Real model capability

Apple adapter 的输入是纯文本，输出类似：

```text
Apple on-device model · language: en (100%) · sentiment: positive (0.64)
```

这是当前开发机操作系统实际提供的本地 NaturalLanguage model 能力，不是 LLM，也不生成开放式回答。它证明了真实模型可以放在同一个 Host policy / signed message boundary 后面，但不证明 Codex、本地生成式模型、第三方进程或长期 Agent runtime 已接入。

## Explicit security boundary

- `HolonAdapter` 只接受 `HolonTextRequest` 并返回 `HolonTextResult`。
- adapter interface 不传入 NearBridge transport、Host identity key、Keychain、文件句柄、workspace、网络 client、shell、`Process` 或动态 tool registry；当前两个实现也不调用这些 API。
- 当前 adapter 与 Host 同进程，因此 protocol 本身不是对恶意第三方代码的强沙箱。第三方实现必须先增加独立进程/extension sandbox，不能仅依赖这个 Swift interface。
- Mac registry 在编译时只注册当前选中 adapter 的固定 capability descriptor。
- Contact 固定为 iPhone request → Mac response → iPhone accept → Mac complete；能力调用仍要求 paired/authenticated fresh session 和 completed contact。
- 空输入、超过 1,200 字符、未知 adapter、未知 capability、错误 correlation 和超过 280 字符的输出会被拒绝。
- NB-3 的 payload encryption 仍未实现。虽然消息有签名、sender/session binding、expiry 和 dedup，仍不应输入秘密。
- 执行发生在用户启动的 App 进程中；没有 daemon、后台常驻、任意远程执行或开放网络传播。

## Decisions required for this checkpoint

- Primary Holon Implementation 选择权属于提供能力的 Mac Host，而不是远端 iPhone。
- NB-6 使用一个稳定 text-insight facade 隔离远端消息和具体模型实现。
- 真实模型选用系统自带、设备端的 Apple NaturalLanguage，避免 API key、模型下载、云和外部许可。
- 确定性 adapter 保留为 fallback 和 adapter contract 对照。
- 活动会话期间不允许切换实现。

## Decisions deliberately open

- Primary Holon Account 与 Host/node identity 的绑定、登录、恢复和实现迁移；
- Codex、Foundation Models、Core ML、自带权重或第三方模型的 adapter；
- 第三方实现的 XPC/App Extension/独立沙箱进程协议；
- 长期运行、资源预算、取消、模型下载、上下文保留与数据删除；
- payload encryption、逐次授权、prompt-injection policy 和模型输出信任标记；
- iPhone 提供能力、双向 Holon 调用和多个 Host/capability 的选择；
- daemon、跨网络、开放传播、支付与信誉。

## Automated evidence

2026-07-21 执行共享测试：**32 tests passed, 0 failures**。

NB-6 新增测试覆盖：

- catalog 只包含一个 Apple real-model adapter 和一个 deterministic fallback；
- Apple adapter 在当前 Mac 上实际返回有界 `language: en` model 结果；
- 选择只允许 catalog 内 implementation ID，并可持久读取；
- registry 只暴露稳定 Primary Holon facade；
- command-like 输入仍作为 inert text；
- 空输入、1,201 字符输入和任意 capability 被拒绝。

执行命令：

```text
env CLANG_MODULE_CACHE_PATH=/private/tmp/nearbridge-nb6-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/nearbridge-nb6-module-cache \
  swift test --disable-sandbox \
  --scratch-path /private/tmp/nearbridge-nb6-swiftpm
```

以下构建均 `BUILD SUCCEEDED`：

```text
xcodebuild -project NearBridge/NearBridge.xcodeproj \
  -scheme NearBridgeMac -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/nearbridge-nb6-mac-derived \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild -project NearBridge/NearBridge.xcodeproj \
  -scheme NearBridgeIOS -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/nearbridge-nb6-ios-derived \
  CODE_SIGNING_ALLOWED=NO build
```

iOS 结果是通用 Device SDK 编译，不是安装、模拟器或真机运行。

## Simulator evidence

**Not run.**

## Physical evidence

2026-07-21 的 NB-6 真机运行观察到：

- Mac 选择 `Apple Natural Language`，显示 on-device real-model disclosure；
- 双端完成 Contact；
- iPhone 调用 `holonia.capability.primary-holon.text-insight.v1`；
- Mac `AppleNaturalLanguageHolonAdapter` 显示 `Execution: succeeded` 并发送 signed `capabilityResult`；
- iPhone 显示 `Execution: succeeded` 和相同结果：`language: en (99%) · sentiment: negative (-0.60)`；
- Mac 收到对应 signed acknowledgement。

完整截图分类、message ID、已观察事实和未测试事项见 [`physical-validation-nb6-2026-07-21.md`](physical-validation-nb6-2026-07-21.md)。

## Next physical test

核心 real-model path 已通过。最小非阻塞下一步是：

1. 断开连接并退出 Mac App。
2. 重新打开，确认选择仍为 `Apple Natural Language`。
3. 连接期间确认 Picker 锁定。
4. 再次断开，切换到 `Deterministic summary demo`，重连并确认同一 facade 返回确定性摘要。

这组测试验证选择持久化和 adapter 可替换性；它不阻塞已经观察到的 NB-6 核心路径。
