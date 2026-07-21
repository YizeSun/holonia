# NearBridge 2:50 Demo Production Package

This package is the source of truth for the final OpenAI Build Week video. The target runtime is **2:50**, leaving ten seconds of safety below the three-minute limit.

## Story in one sentence

An iPhone explicitly discovers and authenticates a nearby Mac, asks the Mac-selected bounded GPT-5.6 Primary Holon one ordinary question, and receives a signed, correlated, auditable answer without exposing files, shell, workspace, or dynamic tools.

## Final capture source

- Use the real iPhone and Mac build from tag `nearbridge-build-week-p0-p1`.
- Record the iPhone with iOS Screen Recording, microphone off.
- Record the Mac app window with `Shift-Command-5`, microphone off.
- Start the Mac recording first, then the iPhone recording. Extra material at either end is expected.
- Use the pairing-code appearance, contact request, and capability invocation as synchronization anchors.
- Record narration separately after the picture edit. Do not narrate while operating the devices.
- Do not use simulator footage for the claimed local-network, pairing, or model-answer path.

## Privacy and readiness checklist

Before recording:

- [ ] Both apps come from `nearbridge-build-week-p0-p1`.
- [ ] Both devices use the same Wi-Fi and Local Network access is enabled.
- [ ] OpenAI GPT-5.6 Sol is selected and the test credential is already stored in Mac Keychain.
- [ ] Never open or type into the API-key field during recording.
- [ ] Enable Focus / Do Not Disturb on both devices.
- [ ] Hide unrelated windows, notifications, email, account names, and desktop files.
- [ ] Use **Demo** mode for the main take; use **Diagnostics** only for the short evidence shot.
- [ ] If showing first-time approval, revoke the existing pair on both devices before recording, then relaunch both apps.
- [ ] Confirm the sample question contains no personal or confidential information.
- [ ] Keep the raw recordings unchanged and make copies for editing.

## Exact operator choreography

1. Launch `NearBridgeMac`, select OpenAI GPT-5.6 Sol, and confirm Host implementation readiness without opening the credential field.
2. Launch `NearBridgeIOS`; leave both apps on **Demo**.
3. Start Mac screen recording, then iPhone screen recording.
4. Show both devices advertising/browsing and listing the other node as untrusted.
5. Tap **Pair** on the iPhone only.
6. Hold on the matching six-digit codes for two seconds.
7. Tap **Codes match — Approve** on Mac, then iPhone.
8. Hold on authenticated state for two seconds.
9. On iPhone tap **Request Primary Holon contact**.
10. On Mac tap **Respond: capability available**.
11. On iPhone tap **Accept capability contact**.
12. On Mac tap **Complete approved contact**.
13. On iPhone choose Sample 1: “Explain in three short sentences why the sky appears blue during the day.”
14. Tap **Ask Mac Primary Holon** once. Do not tap again while execution is in progress.
15. Keep both screens visible until the Mac and iPhone show `Execution: succeeded`.
16. Hold the iPhone answer for four seconds.
17. Scroll both Demo views to the execution receipt. Hold the correlated provider/capability/outcome/acknowledgement information for four seconds.
18. Open **Diagnostics** on one device and show **Export sanitized diagnostics** plus the disclosure that prompt/answer bodies and credentials are omitted. Do not open the Share sheet in the final take.
19. Stop the iPhone recording, then the Mac recording.

## 2:50 picture timeline

| Time | Picture | Required visible proof | Edit note |
| --- | --- | --- | --- |
| 0:00–0:07 | Title card | “NearBridge” / “iPhone → trusted nearby Mac → bounded GPT-5.6 answer” | No logo or music required |
| 0:07–0:21 | iPhone dominant, Mac inset | Physical iPhone UI and Mac app, both in Demo | Establish that this is a native two-device product |
| 0:21–0:38 | 50/50 split | Both peers visible and explicitly labeled untrusted | Add callout: “Discovery ≠ authentication” |
| 0:38–0:53 | 50/50 split, crop to pairing cards | Same six-digit code and approval on both devices | Do not expose unrelated diagnostics |
| 0:53–1:09 | 50/50 split | Authenticated session and four-step contact flow | Speed ramps are allowed only between completed UI states |
| 1:09–1:22 | iPhone dominant | Sample question and one tap on Ask | Callout: “Non-sensitive inert text only” |
| 1:22–1:46 | Mac dominant, iPhone inset | Mac executing selected OpenAI model-only adapter; iPhone receives answer | Keep one real waiting interval or compress gently |
| 1:46–2:05 | iPhone answer | Real answer displayed after signed validation | Hold long enough to read the first two sentences |
| 2:05–2:23 | 50/50 receipts | Same invocation/capability; sent/received acknowledgement | Add callout: “Signed · correlated · acknowledged” |
| 2:23–2:36 | Mac Demo/Diagnostics | Provider disclosure, bounded profile, sanitized export | Add: No files / No shell / No workspace / No tools |
| 2:36–2:44 | Architecture card over blurred app footage | iPhone → authenticated NearBridge → Mac Host policy → GPT-5.6 XPC → signed result | One simple line, no dense diagram |
| 2:44–2:50 | Final card | “Built with Codex · 54 tests · verified on real iPhone + Mac” | End on repository URL |

The edit must end at or before **2:50**.

## Recommended final layout

- Canvas: 1920 × 1080, 30 fps, H.264, AAC 48 kHz.
- Background: near-black `#0B0F14`.
- iPhone: left 42% of frame, full-height with rounded crop and subtle shadow.
- Mac: right 58% of frame, crop tightly to the NearBridge app.
- When one side matters, animate it to 72% width and keep the other as a small inset.
- Captions: lower safe area, maximum two lines, white text on 75% black rounded background.
- Use cuts and short cross-dissolves only. Avoid decorative transitions.
- No copyrighted music. Voice-only is clear and safest.

Narration direction: warm, calm, technically credible, approximately 125 words per minute. Avoid a promotional announcer voice. Generate or record the final narration only after the picture edit is locked so sentence timing can match the real UI.

## Acceptance checklist

- [ ] Runtime is below 3:00; target is 2:50.
- [ ] English narration is audible and captions match it.
- [ ] The working app, not mockups alone, occupies most of the video.
- [ ] The video explicitly says how GPT-5.6 is used.
- [ ] The video explicitly says how Codex was used to build and debug the project.
- [ ] Discovery is never described as authentication.
- [ ] The video does not claim payload encryption, multi-client concurrency, arbitrary Agent tools, or production readiness.
- [ ] No API key, Authorization value, prompt history, notification, email, or unrelated desktop content is visible.
- [ ] The final YouTube upload is public and playable without login.
