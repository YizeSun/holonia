# NearBridge NB-3 Results

Status: **Implementation and automated checkpoint passed; signed integrated workflow/capability traffic was later observed physically, while the dedicated NB-3 ping/disconnect matrix remains pending.**

## Scope

NB-3 在完成 NB-2 mutual confirmation 后创建 fresh session ID，并把轻量消息绑定到：

- 保存的对端 Node ID 与公开签名密钥；
- 当前双方 signed hello 的 transcript hash；
- 每条消息的 schema、UUID、sender、type、sent time、expiry、correlation 和 payload；
- P-256 signature 覆盖全部上述字段。

当前业务探针是 signed ping → signed pong → signed acknowledgement。TCP 提供有序可靠字节流；应用层记录三秒 pong/ack timeout。接收端会拒绝错 sender、错 session、过期、未来时间、错误 lifetime、错误 schema 和签名篡改，重复 UUID 只记录 `duplicateIgnored`，不会再次触发响应。

连接中断会清除 session ID、validator、pending ping 和 acknowledgement 状态。结构化事件包含 phase、role、peer、message UUID、状态、错误和可读说明。

## Security boundary

NB-3 提供 paired-key authentication、session binding 和 message integrity。它**不提供 payload encryption**，也不宣称抵抗已解锁 Host 内的恶意代码、解决账户恢复，或把 Node identity 等同于 Primary Holon identity。

消息 replay set 在每个 session 最多接受 4,096 个不同 UUID；达到上限会 fail closed，而不是清空后接受旧 replay。这是 NB-3 的明确实验限额，不是长期协议参数。

## Decisions required for this checkpoint

- 继续使用 NB-2 P-256 signing identity，不在本阶段额外引入证书体系。
- session ID 来自 fresh pairing transcript，避免把签名消息从一个连接直接搬到另一连接。
- 统一使用整数 epoch milliseconds，避免签名编码中的 Date 精度歧义。
- 默认消息 lifetime 30 秒，允许最大 60 秒，并容许最多 5 秒未来时钟偏差。
- TCP 作为本 checkpoint 的可靠 transport；应用层 ack 用于展示语义完成，不替代 TCP。

## Decisions deliberately open

- payload encryption、forward secrecy、TLS/Noise/其他 secure-channel 方案；
- 密钥轮换、证书链、账户绑定和协议迁移；
- 离线队列、持久消息、重传、流控与 4,096 replay window 的长期参数；
- 后台、睡眠、跨网络恢复和端到端 delivery semantics。

## Automated evidence

2026-07-20 执行 `cd NearBridge && swift test`：20 tests passed, 0 failures。

NB-3 新增测试覆盖：

- signed ping/pong/ack codec、signature 和 correlation；
- 期望 sender 与 session 的认证；
- 同 UUID 第二次到达只返回 duplicate ignored；
- 错 sender、错 session、过期和过远未来时间拒绝；
- payload 被修改但复用旧 signature 时完整性验证失败。

以下构建均 `BUILD SUCCEEDED`：

```text
xcodebuild -project NearBridge/NearBridge.xcodeproj \
  -scheme NearBridgeMac -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/NearBridgeNB3Mac \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild -project NearBridge/NearBridge.xcodeproj \
  -scheme NearBridgeIOS -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/NearBridgeNB3IOS \
  CODE_SIGNING_ALLOWED=NO build
```

iOS 是 Device SDK 构建，不是安装或运行。

## Simulator evidence

**Not run.**

## Physical evidence

2026-07-21 在 authenticated physical session 上观察到带 message UUID 的 signed Contact/capability messages 与 acknowledgements 双向传输。这证明最终集成 build 的 NB-3 message layer 被后续阶段实际使用；本次没有运行 iPhone→Mac 与 Mac→iPhone 的专用 signed ping/pong/ack，也没有验证 disconnect/reconnect session reset。详见 [`physical-validation-2026-07-21.md`](physical-validation-2026-07-21.md)。

## Next physical test

1. 从本 checkpoint 启动两端，并完成 NB-2 配对；如果之前已配对，重新 Pair 以创建 fresh signed transcript。
2. 确认两端同时显示 `Authentication: authenticated`，且 fingerprint 对应已保存记录。
3. iPhone 点 `Send signed ping`，确认收到 signed pong、显示 RTT；Mac 应收到 ping 并最终收到 acknowledgement。
4. Mac 再发送一轮，确认反方向 ping/pong/ack。
5. Disconnect 后确认认证状态回到 idle、Send 按钮禁用；重新 Pair 后 session 恢复，但 session ID 是新的。
6. 保留两端 `authentication.authenticated`、`messageSend`、`messageReceive` 和 message UUID 的截图。

物理通过只适用于本 commit、该设备对和记录的 Wi-Fi；没有执行的篡改/过期注入测试仍保持 Automated 分类。
