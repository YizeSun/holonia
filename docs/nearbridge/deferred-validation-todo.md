# NearBridge 延期验证 TODO

更新时间：2026-07-20

## 1. 用途

本清单保存已经识别、但不阻塞已实现 checkpoint 的真机与网络补充证据。

默认策略：先完成 NearBridge v0 的纵向能力闭环，再集中执行这些环境矩阵。若主线中出现与某一项直接相关的缺陷，可以提前执行对应测试。

这些待办不能被解释为已经通过，也不能把模拟器、代码检查或普通 Wi-Fi 的一次成功外推到其他环境。

## 2. 权限与应用生命周期

- [ ] 在 iPhone 首次请求 Local Network 权限时记录允许路径、系统版本、提示内容和诊断事件。
- [ ] 拒绝 Local Network 权限，确认发现失败能够被解释，且不会被显示为身份或认证失败。
- [ ] 从系统设置重新允许 Local Network 权限，确认无需重新安装即可恢复发现。
- [ ] iPhone App 进入后台后分别等待 30 秒、2 分钟和 10 分钟，记录发现、广告和已有会话行为。
- [ ] 锁定并解锁 iPhone，记录连接状态、断开原因以及恢复路径。
- [ ] 关闭并重新启动 iPhone App，记录旧 peer 消失、新 peer 出现和重复项处理。
- [ ] 关闭并重新启动 Mac App，记录 iPhone 侧的丢失、重新发现和重连行为。
- [ ] Mac mini 睡眠并唤醒，记录广告、浏览、会话和诊断恢复情况。

## 3. 网络环境矩阵

- [ ] 记录当前普通 Wi-Fi 的路由器型号、频段、客户端隔离设置和两端地址类型。
- [ ] 暂时关闭再恢复 iPhone Wi-Fi，记录 peer 丢失、重新发现和会话恢复。
- [ ] 在两个普通家庭或办公路由器上重复核心发现、连接和双向 ping/pong。
- [ ] 使用 Personal Hotspot 重复发现、连接、双向 ping/pong 和重连。
- [ ] 在 guest/restrictive Wi-Fi 上运行，明确记录客户端隔离、Bonjour 可见性和失败诊断。
- [ ] 在网络切换期间发送 ping，确认失败、超时和重连事件不会产生虚假的成功状态。

## 4. 重复性与测量

- [ ] 连续运行 10 次“启动 → 发现 → 连接 → 双向 ping/pong → 断开”，记录成功率。
- [ ] 测量至少 10 次 peer discovery latency 和 connection latency，保存中位数、最大值和失败样本。
- [ ] 验证 service/peer 消失后不会长期留下可连接的 stale entry。
- [ ] 连续发送至少 100 次 ping，记录 RTT 分布、丢失、重复和顺序异常。
- [ ] 记录手动断开到重新连接完成的准确耗时。

## 5. 候选技术补充证据

- [ ] 为 UDP multicast 申请或确认所需 entitlement，并在物理 iPhone 上验证发送与接收。
- [ ] 记录 UDP 在普通 Wi-Fi、Personal Hotspot 和 guest/restrictive Wi-Fi 上的重复、丢失与权限行为。
- [ ] 捕获一次 Mac-originated MultipeerConnectivity ping/pong 真机结果。
- [ ] 捕获 MultipeerConnectivity 断开、重新邀请和恢复后的消息交换结果。

## 6. 不属于延期清单的主线门槛

以下事项不能因为本清单而延期；它们分别是 `NB-2`、`NB-3` 和 `NB-5` 的核心验收内容：

- 未配对设备不能自动成为可信节点；
- 配对需要明确用户授权，并且可以撤销；
- 会话必须认证消息来源并安全处理篡改、重复、过期和格式错误消息；
- Host 只允许调用明确注册的窄能力，并拒绝任意命令执行；
- 关键授权、拒绝、调用和结果必须留下可检查的诊断或审计事件。

## 7. NB-6 Primary Holon 补充证据

- [x] 从 NB-6 commit 在真实 Mac/iPhone 上确认 Apple NaturalLanguage Primary Holon 跨设备调用成功。
  - 2026-07-21：Mac `AppleNaturalLanguageHolonAdapter` 与 iPhone 均显示 `Execution: succeeded` 和相同 `language: en (99%) · sentiment: negative (-0.60)` 结果；Mac 记录 signed result 与 acknowledgement。详见 [`physical-validation-nb6-2026-07-21.md`](physical-validation-nb6-2026-07-21.md)。
- [ ] 关闭并重新打开 Mac App，确认 Primary Holon Implementation 选择持久化。
- [ ] 活动连接期间确认 Picker 锁定，断开后才允许切换 adapter。
- [ ] 切换 deterministic fallback、重新联系并确认执行结果来自新 adapter。
- [ ] 用 command-like inert text、空文本、1,201 字符和重复 invocation 运行拒绝/去重路径。
- [ ] 记录不同语言、neutral/positive/negative 文本在目标系统版本上的 model 输出；不把分类质量当作 NearBridge 认证结论。
- [ ] 使用系统网络观察工具确认 Apple adapter 没有模型云请求；代码检查结论不能代替运行时网络证据。

## 8. 记录规则

完成一项时，在复选框下补充：

1. 日期、设备和操作系统版本；
2. 网络环境；
3. 实际步骤和结果；
4. 相关截图或日志位置；
5. `Observed`、`Simulated`、`Code-inspected` 或 `Not tested` 分类；
6. 是否产生需要回到主线修复的问题。
