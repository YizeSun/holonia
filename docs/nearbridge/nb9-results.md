# NearBridge NB-9 结果

更新时间：2026-07-21

## 状态

NB-9 的实现、共享测试、macOS/通用 iOS 无签名构建、Mac bundle 双 XPC 注册/嵌入检查和单一设备对上的核心物理链路已经完成。真实 iPhone 已通过已认证 NearBridge session 向 Mac 发问；Mac 的受限 OpenAI runner 返回答案，Mac Host 发送 signed typed result，iPhone 显示答案并发回 acknowledgement。错误、重复性、多设备、网络切换和生命周期矩阵仍未完成，因此这不是生产就绪结论。

## 实现路径

```text
iPhone inert-text question
→ authenticated signed capability invocation
→ Mac Host capability registry
→ user-selected OpenAI model-only Primary Holon
→ API key loaded from Mac Host Keychain
→ bounded in-memory XPC request
→ NearBridgeOpenAIRunner.xpc
→ fixed HTTPS OpenAI Responses API request
→ bounded inert-text response
→ signed typed capability result
→ iPhone display
```

远端继续使用稳定 facade：

```text
holonia.capability.primary-holon.text-insight.v1
```

iPhone 不能选择 adapter、provider、model、endpoint 或 tool。Mac 用户只能从 Host 编译时 catalog 选择实现。

## Credential、网络与模型边界

- OpenAI API key 只在 Mac App 输入，保存于 Host Keychain service `org.holonia.nearbridge.openai`。
- key 在一次执行中由 Host 读取并通过本机 XPC 内存请求交给 runner；它不会进入 iPhone/NearBridge 消息、HTTP body、模型 input 或结构化诊断。
- 请求固定到 `https://api.openai.com/v1/responses` 和 `gpt-5.6-sol`；XPC transport 拒绝 HTTP redirect，并再次校验最终 HTTPS host/path。
- Responses request 显式设置 `store: false`；请求结构没有 `tools` 字段。
- provider 返回体、credential 和底层网络错误不会原样发送给 iPhone；它们映射为有限错误类别。
- runner 源 entitlement 只有 App Sandbox 和出站 network client。XPC interface 只接受有界纯文本、credential 和数字上限；不接受路径、workspace、命令、Git、设备控制或动态 tool schema。
- 输入上限 1,200 字符，typed result 上限 4,000 字符，response token 请求上限 2,048；同一 Host 同时只执行一个 Primary Holon invocation，并沿用 session 失效后丢弃结果策略。
- NearBridge 当前仍不宣称 payload encryption。不要输入秘密、credential 或不应发送给 OpenAI 的内容。

这是 model-only API integration，不是 Codex App/CLI 集成。它不继承 Codex 登录状态，也不能读取项目、修改代码、运行命令或长期自治。调用真实 API 可能产生 OpenAI API 用量和费用。

## API 选择

实现使用 OpenAI Responses API 的文本输入/输出，并把当前 model 固定在代码里。官方参考：

- [OpenAI latest model guide](https://developers.openai.com/api/docs/guides/latest-model)
- [OpenAI model catalog](https://developers.openai.com/api/docs/models)
- [Create a response](https://developers.openai.com/api/reference/resources/responses/methods/create)

任何 model 变更都应作为新的已审查 commit，而不是允许 iPhone 或自然语言动态选择。

## Automated

共享测试：50/50 通过，0 failures。

```bash
env CLANG_MODULE_CACHE_PATH=/private/tmp/nearbridge-nb9-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/nearbridge-nb9-module-cache \
  swift test --disable-sandbox \
  --scratch-path /private/tmp/nearbridge-nb9-swiftpm
```

测试覆盖 manifest/profile、registry、Keychain credential validation、固定 endpoint/model、unexpected final URL 拒绝、Authorization header 与 body 分离、`store: false`、omitted tools、bounded response parsing/超长拒绝、provider error sanitization、两个 runner 的 XPC service registration plist，以及可靠消息 schema v2 的 4,000 字符 capability result 上限。

测试使用 stub transport 和虚构测试 credential，不连接 OpenAI。

## Builds 与产物检查

macOS 无签名构建通过：

```bash
xcodebuild -project NearBridge/NearBridge.xcodeproj \
  -scheme NearBridgeMac -configuration Debug -destination platform=macOS \
  -derivedDataPath /private/tmp/nearbridge-nb9-mac-derived \
  CODE_SIGNING_ALLOWED=NO build
```

Mac App 产物同时包含：

```text
NearBridgeMac.app/Contents/XPCServices/NearBridgeModelRunner.xpc
NearBridgeMac.app/Contents/XPCServices/NearBridgeOpenAIRunner.xpc
```

OpenAI XPC bundle identifier、`XPC!` package type、版本和源 entitlement 已检查。

通用 iOS Device SDK 无签名构建通过：

```bash
xcodebuild -project NearBridge/NearBridge.xcodeproj \
  -scheme NearBridgeIOS -configuration Debug -destination generic/platform=iOS \
  -derivedDataPath /private/tmp/nearbridge-nb9-ios-derived \
  CODE_SIGNING_ALLOWED=NO build
```

这些构建不是 Simulator 或 Physical 运行。关闭签名的产物不能证明实际签名 entitlement。

## 核心物理测试

1. 从 NB-9 commit 构建并启动签名 Mac/iPhone App。
2. 只在 Mac 的 OpenAI credential 区域输入测试 API key并保存到 Keychain；不要截图或发送 key。
3. Mac 选择 `OpenAI GPT-5.6 Sol (model-only)`，再完成发现、配对、认证和 Contact。
4. iPhone 输入一个不含敏感信息的普通问题，点击 `Invoke selected Mac Primary Holon`。
5. 确认 iPhone 显示 `Execution: succeeded` 与真实答案，Mac 显示 result/acknowledgement；保存不含 key 的两端截图。
6. 检查签名 XPC entitlement；测试 key 的删除/撤销作为独立 credential-lifecycle 补测记录。

以上第 1 至 5 步已于 2026-07-21 完成，开发签名 XPC entitlement 也已单独检查。测试 key 删除/撤销及其他故障和稳定性项目保存在延期 TODO，不由一次成功外推为已经通过。

## 2026-07-21 首次物理尝试与修复

真实 iPhone/Mac 已观察到 discovery、paired authentication、Contact completed、iPhone question invocation、Mac Host policy acceptance、signed capability failure 和 acknowledgement。模型调用失败在 provider 请求之前：macOS 日志明确记录 `org.holonia.nearbridge.openai-runner` bootstrap lookup 返回 `No such process`，同时 Mac 独立访问固定 endpoint 得到预期 HTTP 401，排除了本机 DNS/TLS/endpoint 可达性问题。

根因是嵌入 XPC 的 `Info.plist` 缺少 `XPCService` dictionary；已为 OpenAI 和本地模型 runner 增加 `XPCService.ServiceType = Application`。这次运行证明失败诊断能安全返回 iPhone，但不证明 OpenAI API key 或真实模型调用。修复后必须重建 Mac App 并重复下一条物理测试。

## 2026-07-21 修复后物理成功

- Mac App 从包含 XPC registration 修复的 `ef28df6` 重建；iPhone 使用兼容的 NB-9 schema。
- 真实 iPhone 与 Mac 在普通 Wi-Fi 上完成发现、已配对身份认证和 Contact。
- iPhone 提交非敏感问题：`Explain in three short sentences why the sky appears blue during the day.`
- iPhone 显示 `Execution: succeeded` 与三句回答；Mac 显示相同回答和 `Execution: succeeded`。
- Mac 诊断显示发送 `capabilityResult · holonia.capability.primary-holon.text-insight.v1`，并收到对应 acknowledgement。
- 两端截图未显示 credential；API key 的值没有被记录到仓库。

该证据只支持一个真实 iPhone/Mac 设备对上的单次 model-only happy path。它不证明并发多客户端、自动路由、离线/限流/provider failure、反复调用、成本边界、payload encryption、文件/命令/tools 或长期 Agent 工作。

## 后续明确 TODO

- 项目只读分析：Host workspace selector、只读文件 broker、上下文预算、逐次授权和敏感数据策略。
- 修改代码与命令执行：独立 worktree、typed tool broker、审批、取消、资源预算、审计和恢复。
- 长期工作：durable job state、生命周期/睡眠/断网恢复和发布级隔离；在此之前不引入 always-running daemon。
