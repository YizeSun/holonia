# NearBridge — Build Week Reviewer Runbook

This is the shortest reproducible path for reviewing NearBridge. It is intentionally explicit about what is automated, what requires two physical Apple devices, and what the current checkpoint does not claim.

## What the reviewer should observe

An iPhone discovers a user-launched Mac app on the same local network, both users approve the same pairing code, and the resulting fresh session authenticates signed messages. The iPhone then requests one fixed text capability. The Mac Host applies an allowlist, invokes its explicitly selected Primary Holon adapter, signs the typed result, and the iPhone validates and displays it.

NearBridge does not expose files, a workspace, shell commands, dynamic tools, device control, or a Codex App/CLI login.

## Requirements

- macOS 14 or newer with Xcode and a Mac capable of running the app.
- iOS 17 or newer on a physical iPhone.
- Both devices on the same Wi-Fi with Local Network permission enabled.
- An Apple Development team for installing the iPhone target.
- Optional: an OpenAI API key for the real GPT-5.6 model-only path. The key is entered only in the Mac app and stored in its Keychain.

## Build

1. Open `NearBridge/NearBridge.xcodeproj`.
2. Select `NearBridgeMac` and run it on the Mac.
3. Select `NearBridgeIOS` and run it on the physical iPhone.
4. After installation, the cable can be removed; keep both apps active and both devices on the same Wi-Fi.
5. In both apps, keep the top segmented control on **Demo**. Use **Diagnostics** only for evidence or troubleshooting.

## Three-minute core path

1. Confirm both apps show discovery as active and list the other node.
2. Tap **Pair** on one device only.
3. Compare the six-digit codes, then tap **Codes match — Approve** on both devices.
4. Confirm `Authentication: authenticated`.
5. On iPhone, tap **Request Primary Holon contact**.
6. On Mac, tap **Respond: capability available**.
7. On iPhone, tap **Accept capability contact**.
8. On Mac, tap **Complete approved contact**.
9. On iPhone, choose Sample 1 and tap **Ask Mac Primary Holon**.
10. Confirm both sides show `Execution: succeeded`; the iPhone displays the answer.
11. Confirm the execution receipt names the provider, capability, peer fingerprint, integrity validation, acknowledgement, and latency.

## Choosing the model path

### Real GPT-5.6 path

Before pairing, select `OpenAI GPT-5.6 Sol (model-only)` in the Mac app. Enter a test key in **Mac Primary Holon**, tap **Save to Keychain**, and confirm the readiness card marks the implementation ready. The isolated XPC runner has explicit network-client access only to make the fixed HTTPS request. The request uses `store: false`, omits tools, bounds input/output, and includes a hashed session safety identifier.

### No-key fallback

Select `Apple Natural Language` or `Deterministic demo` on the Mac before pairing. This validates the same discovery, pairing, contact, capability registry, signed result, and acknowledgement path without an OpenAI credential. It does not prove the GPT-5.6 network request.

## Evidence export

Open **Diagnostics** and select **Export sanitized diagnostics**. The text export contains checkpoint/readiness state, the execution receipt, and up to 100 recent structured events. It intentionally excludes prompt and answer bodies and redacts Authorization headers, bearer tokens, and key-shaped values.

## Expected failure recovery

- No peer: confirm same Wi-Fi, Local Network permission, and no guest-network client isolation; then stop/start discovery.
- Pairing waits: approve the same displayed code on both devices. Discovery alone never grants trust.
- OpenAI implementation not ready: save a valid key on the Mac or disconnect and choose a no-key adapter.
- Execution failed: read the bounded error, correct the credential/network condition, and tap **Retry question** on the iPhone.
- Session ended: reconnect, re-authenticate, repeat the contact workflow, then ask again. Results from an ended session are discarded.

## Current limitations

- One active TCP/authenticated session and one in-flight capability invocation.
- No concurrent multi-client routing, queue, load balancing, or automatic answerer selection.
- No payload-encryption claim beyond the current transport; do not enter secrets.
- No background daemon and no autonomous long-running Agent.
- Physical evidence exists for the NB-9 real model path. The Build Week P0/P1 reorganized UI and new receipt/export layer require a new physical observation before they can be marked physically validated.
