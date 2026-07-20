# NearBridge NB-2 Results

Status: **Implementation and automated checkpoint passed; physical validation pending.**

## Scope

NB-2 在 NB-1 的不可信发现之上增加用户确认的设备配对：

- 每台设备生成 P-256 signing key，私钥和配对记录由本地 Host 的 Apple Keychain 保存；
- Node ID 是公开签名密钥的 SHA-256 摘要，不由 Bonjour 名称或网络地址充当身份；
- 双方在临时 TCP channel 交换 signed hello 和随机 nonce；
- UI 显示由双方 hello transcript 派生的相同六位验证码；
- 初次配对要求双方分别确认验证码；收到网络消息本身不能写入可信记录；
- 双方都签署当前 transcript 后，Host 才保存对端公开密钥；
- 已配对设备仍需对新 transcript 证明私钥持有，但可自动确认已保存的同一公开密钥；
- 用户可以在本地撤销记录；撤销后该 Host 会再次要求人工确认。

连接通道在配对前仍是不可信通道。NB-2 不宣称消息机密性、完整会话认证或 Primary Holon Account 身份；这些分别属于 NB-3 和更后续的账户绑定。

## Decisions required for this checkpoint

- 使用 CryptoKit P-256 signature 和 SHA-256 Node ID 作为可逆的实验实现，而非冻结长期协议。
- 初次配对采用双端确认，比“至少一侧确认”更严格，也更容易明确证明陌生设备不会自动加入。
- 私钥使用 `AfterFirstUnlockThisDeviceOnly` Keychain 可访问性；不会同步到云端。
- 撤销是 Host 本地决定，不尝试远程删除另一台设备的历史记录。
- App 仍然只在用户启动的进程中运行，不增加 daemon。

## Decisions deliberately open

- Secure Enclave、密钥轮换、设备迁移、备份和恢复；
- Node identity 与 Primary Holon Account 的绑定、授权和账户恢复；
- 配对采用二维码、短码或 proximity proof 的最终产品 UX；
- 远端撤销通知与双向删除语义；
- 长期协议版本、证书格式和算法迁移。

## Automated evidence

2026-07-20 执行 `cd NearBridge && swift test`：16 tests passed, 0 failures。

NB-2 新增覆盖：

- 同一保存密钥恢复为同一 Node ID；
- signed hello、transcript hash、六位 code 与 signed confirmation 往返；
- hello 内容被篡改时拒绝；
- peer confirmation 单独到达时不能建立信任，必须有本地批准；
- 本地 paired record 可撤销。

以下构建均 `BUILD SUCCEEDED`：

```text
xcodebuild -project NearBridge/NearBridge.xcodeproj \
  -scheme NearBridgeMac -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/NearBridgeNB2Mac \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild -project NearBridge/NearBridge.xcodeproj \
  -scheme NearBridgeIOS -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/NearBridgeNB2IOS \
  CODE_SIGNING_ALLOWED=NO build
```

iOS 结果是 Device SDK 构建，不是安装或运行。Keychain 的真机行为没有从构建结果外推。

## Simulator evidence

**Not run.**

## Physical evidence

**Pending.** NB-0 的网络结果和 NB-1 的代码不能证明 NB-2 新二进制的配对行为。

## Next physical test

1. 从本 checkpoint 安装并启动 iPhone 与 Mac App，记录两端 `Host identity` fingerprint。
2. 确认双方互相发现，但附近条目仍显示 `untrusted`。
3. 只在一端点 Pair；等待双方显示相同六位 code。
4. 先只在一端 Approve，确认两端尚未都显示 paired；再在另一端 Approve。
5. 确认双方出现 paired record，诊断包含 `approvalRequired`、`locallyApproved`、`remoteConfirmed`、`paired`。
6. 关闭再启动两端 App，确认 Host identity fingerprint 和 paired record 保持不变。
7. 再由一端 Pair，确认双方以新签名 transcript 识别已保存的相同 key，且不把 Bonjour 名称当身份。
8. 在 iPhone 侧 Revoke；再次 Pair 时确认 iPhone 必须人工批准，未批准前不能重新写入信任。

手机运行测试时只需与 Mac 在同一个允许设备互访的 Wi-Fi；安装新 checkpoint 或读取 Xcode 设备日志时再连接数据线即可。结果必须记录为 Physical，失败则保留本 commit 并添加独立修复 commit。
