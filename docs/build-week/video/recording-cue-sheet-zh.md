# NearBridge 原片录制秒表

这里的时间以 **Mac 开始屏幕录制 = 0:00** 计算。允许前后误差三秒；稳定画面和完整状态比准确踩点更重要。最终视频的 `0:00–2:50` 是剪辑时间，不是这张录制秒表。

## 模型请求之前：按主时钟操作

| 录制时间 | 设备 | 操作 |
| --- | --- | --- |
| 0:00 | Mac | 按 `Shift-Command-5` 开始录制 NearBridge App 区域，麦克风关闭 |
| 0:05 | iPhone | 从控制中心开始屏幕录制，麦克风关闭，然后回到 NearBridge |
| 0:08–0:13 | 两端 | 都停在 **Demo**，不要点、不要滚动，保持五秒 |
| 0:13–0:18 | 两端 | 拍清双方发现对方且仍显示 **untrusted**；仍然不操作 |
| 0:18 | iPhone | 点对方节点右侧的 **Pair**；Mac 不点 Pair |
| 0:20–0:24 | 两端 | 相同六位数字出现后，什么都不点，保持四秒 |
| 0:24 | Mac | 点 **Codes match — Approve** |
| 0:27 | iPhone | 点 **Codes match — Approve** |
| 0:30–0:34 | 两端 | 等待 `Session: connected` 和 `Authentication: authenticated`，保持四秒 |
| 0:34 | iPhone | 点 **Request Primary Holon contact** |
| 0:38 | Mac | 点 **Respond: capability available** |
| 0:42 | iPhone | 点 **Accept capability contact** |
| 0:46 | Mac | 点 **Complete approved contact** |
| 0:50–0:54 | 两端 | 拍到 `Contact flow completed`，保持四秒 |
| 0:54 | iPhone | 在问题区域选择 **Sample 1**；如果示例文字已经出现，不必重新输入 |
| 0:58 | iPhone | 只点一次 **Ask Mac Primary Holon** |

## 点 Ask 之后：不要再看绝对秒数

OpenAI API 响应时间不固定。把两端第一次显示 `Execution: succeeded` 的时刻记作 **R**，然后按相对时间继续：

| 相对时间 | 设备 | 操作 |
| --- | --- | --- |
| R 到 R+6 秒 | 两端 | 不操作，拍到两端 `Execution: succeeded` |
| R+6 到 R+12 秒 | iPhone | 让完整问题和答案保持可读，不滚动 |
| R+12 | Mac | 滚到 execution receipt；停五秒 |
| R+18 | iPhone | 滚到 execution receipt；停五秒 |
| R+24 | Mac | 切到 **Diagnostics** |
| R+27 到 R+33 秒 | Mac | 拍到 **Export sanitized diagnostics** 和隐私说明；不要点击导出按钮 |
| R+33 | iPhone | 停止 iPhone 录屏 |
| R+36 | Mac | 停止 Mac 录屏 |

## 如果状态来得比秒表慢

- 不要为了追赶秒表提前点击。
- 等目标按钮可用或目标状态出现，再继续下一步。
- 每次关键状态出现后至少保持三秒。
- 如果点错、重复发送、弹出通知或中途失败，停止两端录制并从头录一条新 take；不要尝试在同一条原片里补救。

最终只需要交付最干净的一条 Mac 原片和一条与之对应的 iPhone 原片。Holonia 图卡、旁白、字幕和最终 `0:00–2:50` 节奏由后期剪辑完成。
