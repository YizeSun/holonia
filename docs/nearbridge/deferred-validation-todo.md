# NearBridge 延期验证 TODO

更新时间：2026-07-21

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

## 8.1 NB-8 隔离本地模型 runner 补充证据

- [ ] 从 NB-8 commit 构建并运行签名 Mac App，确认嵌入的 `NearBridgeModelRunner.xpc` 能启动。
- [ ] 用 `codesign` 检查实际 Mac App 与 XPC entitlement，确认 runner 只有 App Sandbox，未获得 network client/server、用户文件或临时文件例外。
- [ ] 真实 iPhone 发起普通文本请求，确认 Mac XPC 执行 Apple Foundation Models，iPhone 收到并显示 signed typed answer。
- [ ] 保存两端结构化诊断截图，区分 Host 接受、runner 开始/完成、signed result 和 acknowledgement。
- [ ] 运行空输入、1,201 字符、重复点击、runner timeout 以及认证会话提前断开的拒绝/丢弃路径。
- [ ] 用运行时网络观察确认本地 runner 不产生网络连接；源码 entitlement 检查不能替代这项证据。

## 9. 通用 Primary Holon 平台后续功能 TODO

以下不是稳定性补测，而是明确尚未实现的产品/安全层。保存在这里是为了防止当前 model-only 平台被误解为已经拥有 Codex 工具权限。

### 9.0 NB-9 OpenAI model-only 补充证据

- [x] 从 NB-9 commit 构建并运行签名 Mac/iPhone App，确认 `NearBridgeOpenAIRunner.xpc` 能启动。
  - 2026-07-21：包含 `ef28df6` XPC registration 修复的 Mac bundle 完成真实 model-only 请求并返回结果。
- [x] 用 `codesign` 检查实际 XPC entitlement，确认 App Sandbox 与 network client 边界，没有文件、命令、automation 或 network server entitlement。
  - 开发签名产物同时包含 `get-task-allow`；该项不等同于发布签名审核。
- [x] 在 Mac App 内保存有效 OpenAI API key，确认 Keychain 状态；key 未被输入 iPhone、诊断、截图或仓库。
- [x] Mac 选择 OpenAI model-only Primary Holon，完成配对、认证和 Contact；iPhone 发起普通非敏感问题并显示 signed typed answer。
- [x] 保存两端结构化诊断截图，确认 Host result、signed result 和 acknowledgement；可见事件与截图不含 credential。
- [ ] 验证缺失/无效 key、离线、401/403、429、provider failure、超长结果、重复点击和 session 提前结束路径。
- [ ] 删除 Keychain API key、重启 Mac App并确认状态保持未配置；必要时在 OpenAI 控制台撤销测试 key。
- [ ] 记录真实 API model、延迟和用量；自动化 stub 测试不能替代 provider 行为或费用证据。
- [ ] 用第二台真实 iPhone 依次完成发现、配对、断开和重连，确认 trust registry 能保存多个独立身份且不会串用 session/result。
- [ ] 在支持并发多客户端之前，定义显式 session selector、队列、公平性、rate limit、取消和 result correlation；不得把一个问题广播给所有已配对设备。

### 9.1 让 Codex 读取项目并分析

- [ ] 用户在 Mac Host 上显式选择允许的 workspace；远端不能提交任意路径。
- [ ] 建立只读文件 broker，默认拒绝 workspace 外路径、隐藏凭据、Keychain、SSH 和系统目录。
- [ ] 定义文件类型、单文件大小、总上下文预算、symlink 和 package cache policy。
- [ ] 每次分析显示将读取的范围，并支持批准、取消和完整审计。
- [ ] 对 prompt injection、二进制文件、超大仓库和敏感数据泄漏做威胁建模与测试。

### 9.2 让 Codex 修改代码、运行命令并长期工作

- [ ] 写入必须使用独立 worktree/临时分支，并提供 diff 审阅与可恢复 rollback。
- [ ] 命令只能通过 typed allowlist tool broker；不能把自然语言直接拼接成 shell。
- [ ] 高风险命令、网络访问、安装依赖、凭据读取和外部副作用逐次审批。
- [ ] 独立 runner 的 CPU、内存、磁盘、token、时间和并发预算，以及强制取消。
- [ ] 崩溃、睡眠、断网和 Host 重启后的 durable job state 与安全恢复。
- [ ] 输出、工具调用、批准、文件 diff 和外部副作用形成可导出审计链。
- [ ] 在完成安全评审与真机/故障矩阵前，不引入 always-running daemon。

## 10. Build Week 最终展示状态

- [x] 从最终 Build Week P0/P1 commit 在真实 iPhone/Mac 上完成 reviewer runbook，保存两端相关联回执与 sanitized diagnostics；2026-07-21 单一设备对主路径通过。
- [ ] 运行 invalid key 或离线失败 → 修复 → Retry，确认错误清晰、key/provider body 不泄漏。
- [x] 冻结 2:50 英文脚本、点击顺序、旁白、字幕和 side-by-side 版式。
- [x] 使用物理 iPhone 与 Mac 作为核心证明；最终演示不依赖 simulator 证明网络、配对或模型路径。
- [x] 分开录制 iPhone/Mac 原生画面并同步，完成隐私检查和最终导出。
- [x] 上传 YouTube：https://youtu.be/4s-6gypJUYA。
- [ ] 在无登录 private browser 中确认最终 YouTube 可见性。
- [ ] 在 Devpost 完成 repo、README/test instructions 与 `/feedback` Codex Session ID 字段并提交。
