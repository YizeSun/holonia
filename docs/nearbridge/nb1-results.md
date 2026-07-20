# NearBridge NB-1 Results

Status: **Implementation and automated checkpoint passed; physical validation pending.**

## Scope

NB-1 只实现不可信节点发现：

- iPhone 与 Mac 使用 Bonjour `_nearbridge-v0._tcp` 广播并浏览最小临时引用；
- 去重并记录 peer found/lost、首次与最近发现时间、可选设备角色提示；
- 所有发现对象固定为 `untrusted`，不广播完整能力或私人内容；
- NB-1 明确拒绝入站、出站传输会话及消息发送；
- UI 与结构化事件同时说明 discovery is not authentication。

配对、稳定身份、密钥、认证消息和能力调用均未在本阶段实现。

## Decisions required for NB-1

- 暂用 Bonjour + Network.framework 作为发现候选；服务名仅承担临时 UI 提示。
- App 由用户启动后在进程内工作，不引入 daemon。
- Local Network 状态由 Network.framework 的 ready/waiting/failure 信号解释；Apple 没有在此处提供可直接读取的授权布尔值，因此 `attentionRequired` 也可能表示网络不可用。

## Decisions deliberately open

- NB-2 的确认方式、稳定身份格式、密钥存储、轮换与恢复；
- 发现与认证会话最终是否继续共用 Network.framework；
- 后台、锁屏、热点、企业或隔离 Wi-Fi 的最终产品行为；
- Primary Holon Account 与本地节点身份的绑定。

## Automated evidence

2026-07-20 在 macOS 26.5.1、Xcode 26.5、Swift 6.3.2 环境执行：

```text
cd NearBridge && swift test
```

结果：11 tests passed, 0 failures。NB-1 新增测试覆盖发现去重、firstSeen/lastSeen、peer lost、始终不可信、阶段化结构事件，以及 NB-1 禁止传输会话的策略。

```text
xcodebuild -project NearBridge/NearBridge.xcodeproj \
  -scheme NearBridgeMac -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/NearBridgeNB1Mac \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild -project NearBridge/NearBridge.xcodeproj \
  -scheme NearBridgeIOS -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/NearBridgeNB1IOS \
  CODE_SIGNING_ALLOWED=NO build
```

结果：两个 target 均 `BUILD SUCCEEDED`。iOS 结果是 Device SDK 构建，不是安装或运行。

## Simulator evidence

**Not run.** 本 checkpoint 没有模拟器行为结论。

## Physical evidence

**Pending.** NB-0 的真机成功不能自动外推到 NB-1 的新二进制、服务类型和 session gate。

## Next physical test

手机不需要用数据线连接 Mac；两端需要在同一个允许客户端互访和 Bonjour/mDNS 的 Wi-Fi 上。数据线只用于安装新版和读取 Xcode 设备日志。

1. 从本 checkpoint 构建并分别启动 iPhone 与 Mac App。
2. 首次弹出 Local Network 权限时选择 Allow。
3. 确认两端都显示 `NB-1`，且状态进入 browsing/peer discovered。
4. 确认 iPhone 只出现一个 Mac 条目，Mac 只出现一个 iPhone 条目，二者均标记 `untrusted`。
5. 确认 UI 没有 Connect、Send、能力调用入口。
6. 在一端 Stop，确认另一端记录 peer lost；再次 Start，确认重新发现且没有重复条目。
7. 保存两端截图以及 `peerFound.untrusted` / `peerLost.lost` 诊断。

通过后，把设备、系统、Wi-Fi 环境和截图路径追加到本文件，并可对对应 commit 添加 `nb-1-physical-pass` 标签。若失败，保留原 checkpoint，再以独立修复 commit 处理。
