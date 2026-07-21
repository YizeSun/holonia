# NearBridge NB-8 结果

更新时间：2026-07-21

## 状态

NB-8 的实现、共享测试、macOS/通用 iOS 无签名构建和 Mac bundle 嵌入检查已完成。签名后的 entitlement、XPC 运行时边界和真实 iPhone → Mac → iPhone 生成结果尚未运行，不能记为 Physical 通过。

## 实现路径

```text
iPhone signed capability invocation
→ authenticated Mac Host policy
→ capability registry resolves selected Primary Holon
→ bounded XPC request
→ NearBridgeModelRunner.xpc
→ Apple Foundation Models with tools: []
→ bounded XPC response
→ signed typed capability result
→ iPhone display
```

NB-8 复用已经真机验证过的稳定 capability facade：

```text
holonia.capability.primary-holon.text-insight.v1
```

切换具体 adapter 不会让远端选择执行实现，也不会扩大该 facade 的权限。

## 隔离与限制

- runner 是嵌入 Mac App 的独立 XPC service；源 entitlement 只有 App Sandbox。
- XPC interface 只接受 Codable 有界纯文本请求和结果，不接受路径、workspace、凭据、命令或工具定义。
- Foundation Models session 显式使用 `tools: []`，并由固定 instruction 限制为纯文本回答。
- NearBridge 输入上限为 1,200 字符；runner protocol 输出上限为 512 字符，模型 generation 上限为 384 tokens。
- XPC 调用 90 秒超时；Host 同时只允许一个模型 invocation。
- authenticated session 在结果返回前结束时，Host 丢弃结果，不把它发送到新会话。
- 本 checkpoint 没有 remote model、文件 broker、shell、Git、动态工具或常驻 daemon。

这些是实现和源码检查结论。只有签名产物与运行时观察才能证明目标设备上的 entitlement 和进程行为。

## Automated

共享测试：39/39 通过，0 failures。

```bash
env CLANG_MODULE_CACHE_PATH=/private/tmp/nearbridge-nb8-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/nearbridge-nb8-module-cache \
  swift test --disable-sandbox \
  --scratch-path /private/tmp/nearbridge-nb8-swiftpm
```

测试包含 generic manifest/registry 行为、XPC request/response 边界、超时映射，以及 Foundation Models adapter 的 execution profile 和 capability routing。

## Builds 与产物检查

macOS 无签名构建通过：

```bash
xcodebuild -project NearBridge/NearBridge.xcodeproj \
  -scheme NearBridgeMac -configuration Debug -destination platform=macOS \
  -derivedDataPath /private/tmp/nearbridge-nb8-mac-final-derived \
  CODE_SIGNING_ALLOWED=NO build
```

构建产物包含：

```text
NearBridgeMac.app/Contents/XPCServices/NearBridgeModelRunner.xpc
```

XPC bundle identifier、`XPC!` package type 和 FoundationModels linkage 已检查。

通用 iOS Device SDK 无签名构建通过：

```bash
xcodebuild -project NearBridge/NearBridge.xcodeproj \
  -scheme NearBridgeIOS -configuration Debug -destination generic/platform=iOS \
  -derivedDataPath /private/tmp/nearbridge-nb8-ios-final-derived \
  CODE_SIGNING_ALLOWED=NO build
```

这不是 Simulator 或 Physical 运行。

## 下一条物理测试

1. 从 NB-8 commit 构建签名 Mac/iPhone App。
2. 在 Mac 选择 Apple Foundation Models Primary Holon。
3. 完成发现、配对、认证和 Contact。
4. iPhone 输入无敏感信息的普通问题并发起调用。
5. 确认 Mac XPC runner 成功、iPhone 显示回答，保存两端结构化诊断。
6. 检查签名 XPC entitlement，并观察 runner 是否产生网络连接。

在以上步骤完成前，NB-8 的 Physical 状态保持 `Not tested`。

## 2026-07-21 XPC packaging correction

NB-9 首次物理调用暴露出两个嵌入 XPC 的 `Info.plist` 缺少 `XPCService` dictionary。bundle 虽然位于 `Contents/XPCServices`，launchd 仍无法按 service name 注册它。OpenAI runner 的系统日志为 `failed lookup ... error = 3: No such process`，失败发生在任何 provider 网络请求之前。

后续修复为两个 runner 都加入 `XPCService.ServiceType = Application`。因此 NB-8 的旧 bundle 嵌入检查不再被解释为 runner 可启动证据；必须从修复后的 commit 重建并运行上述物理测试。
