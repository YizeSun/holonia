# NearBridge NB-7 Results

Status: **Implementation, shared tests, and unsigned target builds complete; physical validation not run.**

## Scope

NB-7 把 NB-6 的编译时 Primary Holon 描述收敛为最小通用平台 contract：

```text
HolonManifest v1
→ one or more typed capability declarations
→ AdapterExecutionProfile
→ duplicate-safe HolonCapabilityRegistry
→ stable capability-to-implementation registration
```

`HolonManifest` 包含稳定 implementation/vendor ID、显示元数据、runtime disclosure、capability schema/字符上限和 execution profile。manifest 可以编码为 sorted-key canonical JSON，为后续签名准入提供稳定输入，但 NB-7 本身没有开放动态第三方代码。

## Security boundary

- 当前 profile validator 拒绝文件读取、文件写入、命令执行和动态工具。
- 网络、凭据和 isolation 必须使用受支持的组合，不能任意混搭权限声明。
- NB-6 的内置 Apple NaturalLanguage 与 deterministic adapter 现在通过 manifest 注册，但仍在 Host 进程执行；profile 对诚实代码提供 contract，不是恶意代码的 OS 沙箱。
- `appSandboxedXPC` 与 OpenAI model-only profile 是后续 runner/provider 的可验证声明；NB-7 不声称对应执行路径已经实现。
- iPhone 仍不能选择 Mac 的 implementation、提交文件路径、URL、命令、model path 或工具。
- NB-3 payload encryption 仍未实现，不能输入秘密。

## Automated evidence

2026-07-21 执行共享测试：**37 tests passed, 0 failures**。

NB-7 新增测试覆盖：

- 内置 manifest canonical JSON round trip；
- registry 将稳定 capability 映射到 implementation 与 execution profile；
- 跨 implementation 的重复 capability 被拒绝；
- 文件/命令/动态工具授权被 profile validator 拒绝；
- 不支持的 manifest version 被拒绝。

执行命令：

```text
env CLANG_MODULE_CACHE_PATH=/private/tmp/nearbridge-nb7-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/nearbridge-nb7-module-cache \
  swift test --disable-sandbox \
  --scratch-path /private/tmp/nearbridge-nb7-swiftpm
```

以下 unsigned 构建均 `BUILD SUCCEEDED`：

```text
xcodebuild -project NearBridge/NearBridge.xcodeproj \
  -scheme NearBridgeMac -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/nearbridge-nb7-mac-derived \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild -project NearBridge/NearBridge.xcodeproj \
  -scheme NearBridgeIOS -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/nearbridge-nb7-ios-derived \
  CODE_SIGNING_ALLOWED=NO build
```

iOS 结果是通用 Device SDK 编译，不是安装、模拟器或真机运行。

## Physical evidence

**Not run.** NB-7 UI 的 `Physical validation pending` 是正确状态。NB-6 的真机结果不能外推为 NB-7。

## Next checkpoint

NB-8 将实现 Host 管理的本地生成模型 runner，并用独立 app sandbox、无网络 entitlement、无文件/命令/tool interface 的 XPC boundary 验证 `sandboxedLocalModel` profile。只有实际 runner 与签名构建检查完成后，才能把该 profile 从 contract 变为已实现隔离边界。
