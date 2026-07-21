# NearBridge Build Week 真机录制清单

这份清单只负责录制干净的 Mac 与 iPhone 原片。不要边操作边念旁白，也不要提前裁剪或转码；画面锁定后再生成旁白、字幕和最终左右分屏成片。

## 录制前

1. 确认 Xcode 运行的是 tag `nearbridge-build-week-p0-p1` 对应的最终 NB-9 Build Week 版本。
2. Mac 与真实 iPhone 连接同一个 Wi-Fi，并确认两端 Local Network 权限已开启。
3. 两端打开勿扰模式，关闭会泄露个人信息的窗口和通知。
4. Mac 端提前选择 **OpenAI GPT-5.6 Sol**，确认测试 API key 已在 Keychain 中；录制时不要打开或输入 API key。
5. 两端切换到 **Demo**，主流程不要停留在 Diagnostics。
6. 如果要展示完整首次配对，先在两端 **Revoke** 已保存的配对，再重新启动两个 App。

## 开始录制

1. Mac 按 `Shift-Command-5`，选择只录 NearBridge App 所在区域，麦克风选择“无”，开始录制。
2. iPhone 打开控制中心，长按录屏按钮，确认麦克风关闭，开始录制。
3. 等待三秒再操作。Mac 比 iPhone 先开始、多录几秒是正确的。

## 一次完成的点击顺序

1. 两端停留在发现界面，拍到对方设备仍标记为 **untrusted**。
2. 只在 iPhone 点 **Pair**。
3. 六位数字出现后停两秒，拍清楚两端数字相同。
4. Mac 点 **Codes match — Approve**，然后 iPhone 点同名按钮。
5. `authenticated` 出现后停两秒。
6. iPhone 点 **Request Primary Holon contact**。
7. Mac 点 **Respond: capability available**。
8. iPhone 点 **Accept capability contact**。
9. Mac 点 **Complete approved contact**。
10. iPhone 选择示例问题：`Explain in three short sentences why the sky appears blue during the day.`
11. iPhone 只点一次 **Ask Mac Primary Holon**，等待两端显示 `Execution: succeeded`。
12. iPhone 答案画面停四秒，不要遮挡答案。
13. 两端滚到 execution receipt，分别停四秒，拍到 capability、outcome、acknowledgement 等字段。
14. 任选一端短暂进入 **Diagnostics**，拍到 **Export sanitized diagnostics** 以及不导出 prompt、answer、credential 的说明；不要真的打开分享面板。

## 停止与交付

1. 先停止 iPhone 录屏，再停止 Mac 录屏。
2. 原片不要裁剪、加速、压缩、改帧率或加入旁白。
3. 文件命名为：
   - `NearBridge-iPhone-raw.mp4` 或系统生成的原始 `.mov`
   - `NearBridge-Mac-raw.mov`
4. 把两份文件直接附到 Codex 任务，或告诉 Codex 它们的本地绝对路径。

之后 Codex 会用配对码出现、contact 请求和 capability invocation 三个事件校准时间轴，完成画面裁切、左右分屏、重点放大、英文字幕、旁白时序和最终导出。
