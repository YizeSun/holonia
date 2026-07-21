# NearBridge 2:50 Demo Production Package

This package is the source of truth for the final OpenAI Build Week video. The target runtime is **2:50**, leaving ten seconds of safety below the three-minute limit.

## Editable cut

The working Remotion edit lives in [`remotion/`](remotion/). It contains the
locked 2:50 composition, tracked story cards, captions, evidence stills, and
render commands. Raw recordings, generated narration, and rendered MP4 files
stay local and are ignored by Git.

For the supplied takes, the Mac recording is longer. The edit preserves the
shared ending and removes 361 frames at 30 fps (approximately 12.03 seconds)
from the **beginning of the Mac recording only**. This is the synchronization
rule for this cut.

## Story in one sentence

Holonia helps people and Agents reach capabilities beyond themselves; NearBridge is its first working implementation slice, proving that an iPhone can explicitly trust a nearby Mac, invoke one Host-controlled GPT-5.6 capability, and receive a signed, auditable result without exposing files, shell, workspace, or dynamic tools.

## Three-act structure

1. **Holonia vision:** when current capability is insufficient, find the right Holon, establish trusted contact, delegate work, and receive a verifiable result.
2. **NearBridge foundation:** show which Host-controlled interfaces are working now and which planned Holonia capabilities they can safely support later.
3. **Physical proof:** demonstrate the real iPhone → authenticated Mac → selected model-only adapter → signed answer path.

The first two acts must motivate the physical proof, not compete with it. Real app footage begins as background by 0:34, and the formal device interaction begins at 1:06.

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
4. Hold both Demo landing views still for five seconds before touching either device. This supplies clean establishing footage under the Holonia/NearBridge introduction.
5. Show both devices advertising/browsing and listing the other node as untrusted.
6. Tap **Pair** on the iPhone only.
7. Hold on the matching six-digit codes for two seconds.
8. Tap **Codes match — Approve** on Mac, then iPhone.
9. Hold on authenticated state for two seconds.
10. On iPhone tap **Request Primary Holon contact**.
11. On Mac tap **Respond: capability available**.
12. On iPhone tap **Accept capability contact**.
13. On Mac tap **Complete approved contact**.
14. On iPhone choose Sample 1: “Explain in three short sentences why the sky appears blue during the day.”
15. Tap **Ask Mac Primary Holon** once. Do not tap again while execution is in progress.
16. Keep both screens visible until the Mac and iPhone show `Execution: succeeded`.
17. Hold the iPhone answer for four seconds.
18. Scroll both Demo views to the execution receipt. Hold the correlated provider/capability/outcome/acknowledgement information for four seconds.
19. Open **Diagnostics** on one device and show **Export sanitized diagnostics** plus the disclosure that prompt/answer bodies and credentials are omitted. Do not open the Share sheet in the final take.
20. Stop the iPhone recording, then the Mac recording.

## 2:50 picture timeline

| Time | Picture | Required visible proof | Edit note |
| --- | --- | --- | --- |
| 0:00–0:12 | Holonia title/vision card | “Capability discovery and work connection” | Establish the larger project before naming the implementation slice |
| 0:12–0:23 | Holonia flow card | Request → trusted contact → delegation → delivery → acceptance | Keep this conceptual and readable; do not imply the full flow is implemented |
| 0:23–0:34 | Principle card | “Holon proposes · Host enforces · Human authorizes” | This is the motivation for the security boundary |
| 0:34–0:44 | NearBridge relationship card over physical-device B-roll | “NearBridge · Holonia’s first working edge” | Begin showing real app footage here |
| 0:44–0:55 | Platform card | Current Host-controlled layers: trust, session, workflow, contract, execution, receipt | Show interface names visually; narration explains their function |
| 0:55–1:06 | Platform card future row | Signed adapters → controlled context → approved tools → broader Holonia | Clearly label this row **NEXT / LATER**, not current functionality |
| 1:06–1:17 | 50/50 physical split | Both peers visible and explicitly labeled untrusted | Add callout: “Discovery ≠ authentication” |
| 1:17–1:30 | Pairing close-up | Same six-digit code and approval on both devices | Do not expose unrelated diagnostics |
| 1:30–1:44 | 50/50 split | Fresh authenticated session and four-step Primary Holon contact flow | Speed ramps only between completed UI states |
| 1:44–1:53 | iPhone dominant | Sample question and one tap on Ask | Callout: “Non-sensitive inert text only” |
| 1:53–2:14 | Mac dominant, iPhone inset | Mac runs selected GPT-5.6 model-only XPC; no files, shell, workspace, or tools | Preserve one real waiting interval or compress gently |
| 2:14–2:26 | iPhone answer | Signed result displayed after sender/session/expiry/correlation validation | Hold long enough to read the answer |
| 2:26–2:35 | 50/50 receipts and brief Diagnostics crop | Correlated outcome/acknowledgement plus sanitized-export disclosure | Callout: “Signed · correlated · acknowledged” |
| 2:35–2:46 | Architecture/final proof card | Codex engineering role · nine checkpoints · 54 tests | Do not claim production readiness |
| 2:46–2:50 | Final card | “NearBridge · The first working edge of Holonia” | End on repository URL |

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
- [ ] The opening clearly distinguishes the Holonia vision from the currently implemented NearBridge slice.
- [ ] Current interfaces and future capabilities are visually separated as **NOW**, **NEXT**, and **LATER**.
- [ ] Discovery is never described as authentication.
- [ ] The video does not claim payload encryption, multi-client concurrency, arbitrary Agent tools, or production readiness.
- [ ] No API key, Authorization value, prompt history, notification, email, or unrelated desktop content is visible.
- [ ] The final YouTube upload is public and playable without login.
