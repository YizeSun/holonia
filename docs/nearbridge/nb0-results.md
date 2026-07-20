# NearBridge NB-0 Results

Status: **NB-0 core ordinary-Wi-Fi path achieved — Bonjour discovery, connection, both-origin ping/pong, manual disconnect, reconnect, and post-reconnect ping/pong succeeded. Permission edge cases, UDP, and wider network-matrix evidence remain follow-up work.**

Classification used below:

- **Observed** — reproduced on stated physical devices.
- **Simulated** — reproduced in a simulator.
- **Code-inspected** — supported by compilation, unit tests, or implementation inspection, but not by a physical network run.
- **Not tested** — still requires execution evidence.

## 1. Environment

| Item | Value | Classification |
| --- | --- | --- |
| Mac mini model | Mac16,10 | Code-inspected from local system inventory |
| Mac mini chip/memory | Apple M4, 16 GB | Code-inspected from local system inventory |
| macOS | 26.5.1 (25F80) | Code-inspected from local system inventory |
| Xcode | 26.5 (17F42) | Code-inspected |
| Swift | 6.3.2 | Code-inspected |
| SDKs used | macOS 26.5, iOS 26.5, iOS Simulator 26.5 | Code-inspected/build output |
| Apple Developer signing | Xcode-managed Apple Development profile | Observed during physical install; the initial CLI inventory had returned zero identities |
| Physical iPhone | Connected iPhone 14 Pro Max (`iPhone15,3`) | Observed in CoreDevice and Xcode run metadata |
| iPhone model/iOS | iPhone 14 Pro Max, iOS 26.5.2 (23F84) | Observed in CoreDevice and Xcode run metadata |
| Ordinary Wi-Fi | iPhone and Mac discovered each other; router details not recorded | Observed, with incomplete environment metadata |
| Personal Hotspot | Unknown | Not tested |
| Restrictive/guest Wi-Fi | Unknown | Not tested |

The iOS build used an iPhone 17 Pro iOS 26.5 simulator destination only as a compile destination. The app was not launched there, so no simulator discovery claim is made.

## 2. Implemented experiments

- **Code-inspected:** Bonjour advertisement/browse with minimal metadata plus a newline-framed, reusable `NWConnection` TCP session, inbound acceptance, disconnect state, and one two-second reconnect path.
- **Code-inspected:** MultipeerConnectivity advertising/browsing, invitation/session setup with required framework encryption, reliable data messages, and explicit rejection of streams/resources.
- **Code-inspected:** `NWConnectionGroup` UDP multicast probe at `239.255.42.99:42424`; it has no session, automatic response, forwarding, or action dispatch.
- **Code-inspected:** Both session candidates decode only version-1 ping/pong JSON. Valid pings receive a correlated pong. Duplicate message IDs are ignored by the shared controller.
- **Code-inspected:** Structured diagnostics are shown in-app and emitted through the `org.holonia.nearbridge.nb0` OSLog subsystem.

## 3. Tests actually run

- **Code-inspected/tested locally:** `swift test` built the shared module and ran seven unit tests: ping/pong JSON round trips, correlation, unsupported schema, malformed JSON, invalid ping correlation, duplicate ID handling, and structured event content/encoding. Result: 7 passed, 0 failed.
- **Code-inspected/build-tested:** macOS Debug app build with signing disabled. Result: succeeded.
- **Code-inspected/build-tested:** generic iOS device-SDK Debug app build with signing disabled. Result: succeeded; this does not install or run the app.
- **Code-inspected/build-tested:** iOS Simulator Debug app build for iPhone 17 Pro / iOS 26.5 with signing disabled. Result: succeeded.
- **Observed:** signed iOS app installed and launched on physical `iPhone15,3`; the macOS app launched on the Mac mini.
- **Observed:** Bonjour advertisement/discovery worked in both directions without manual IP entry and an experimental TCP session reached `connected` on both devices.
- **Observed:** a Mac-originated ping received a correlated pong with a displayed 43.8 ms RTT.
- **Observed after UI fix:** Bonjour remained connected while both devices originated ping/pong exchanges. Physical RTT samples shown in the UI include 25.0 ms, 51.4 ms, and 250.5 ms.
- **Observed after UI fix:** MPC completed an iPhone-originated ping/pong round trip with 34.5 ms displayed RTT.

## 4. Physical-device results

**Observed on 2026-07-20:** both user-launched apps ran on the Mac mini and physical iPhone; each discovered the other's ephemeral Bonjour service; both reported a connected TCP session; a Mac-originated ping completed with pong and 43.8 ms RTT. This proves one physical bidirectional request/response path at the TCP/message level because the iPhone received the ping and sent the pong.

**Observed failure:** initiating ping from the iPhone did not complete or produce sufficient diagnostics. A disconnect/reconnect cycle occurred shortly beforehand, and the UI still allowed additional Connect actions while connected. The implementation was subsequently changed to reject/disable redundant connections, distinguish last-sent from last-received messages, log a three-second ping timeout, require a ready transport before sending, and avoid labeling unrelated framework failures as discovery failures. These changes are **Code-inspected/build-tested** until the next physical run.

**Observed in the first hardened retest:** the iPhone-originated ping logged `messageSend.sending`, followed about 33 ms later by `frameworkError.sendFailed` and disconnection; no pong arrived and the three-second timeout fired. Mac Network.framework debug logs show the session used a satisfied, viable `en0` IPv6 link-local path. At failure time the Mac received a TCP FIN from the iPhone without receiving application payload. The transport was subsequently changed to serialize start, connect, disconnect, send, and connection state handling on one Network queue. Raw error domain/code display was also added and redundant timeout reporting after immediate send failure was removed. These latest changes are **Code-inspected/build-tested** pending another physical run.

**Observed in the serialized-queue retest:** the same iPhone-originated failure reproduced. The iPhone reported `Network.NWError (89)`, `POSIXErrorCode(rawValue: 89): Operation canceled`, about 32 ms after the send attempt. The immediate send failure correctly cleared the pending ping without adding a redundant timeout. Mac system logs again showed an incoming TCP FIN from the iPhone with zero application reads/writes before closure.

**Root cause identified by the MPC comparison:** on iOS, the `Send ping` and `Disconnect` buttons shared one SwiftUI `List` row with automatic button style. A tap on Send could activate both row buttons. In the MPC run, the iPhone logged a successful reliable send and disconnection in the same millisecond; the Mac received the ping, recorded its pong response, then found the session already disconnected. This cross-transport evidence explains the Bonjour `ECANCELED`/FIN as an application UI action rather than a Network.framework transport limitation.

**Observed after the button fix:** explicit independent button styles eliminated the coupled disconnect. MPC stayed connected while an iPhone ping received a correlated pong at 34.5 ms RTT. Bonjour stayed connected across both directions: the iPhone originated ping #2 and received pong #2 at 51.4 ms, while the Mac recorded receipt/response for the iPhone ping and separately originated pings that received correlated pongs, with displayed RTT samples of 25.0 ms and 250.5 ms. The previous `ECANCELED` failure is resolved as a UI defect.

**Observed controlled reconnect on 2026-07-20:** the tester manually disconnected the Bonjour session, reconnected from one side, and then sent iPhone ping #3. The iPhone received correlated pong #3 with 27.8 ms displayed RTT while the session remained usable. This satisfies the core NB-0 requirement for one tested reconnection path on the ordinary-Wi-Fi device pair. Exact disconnect-to-connected elapsed time was not recorded.

## 5. Simulator-only results

**Not tested at runtime.** The simulator target compiled, but compilation is not network validation.

## 6. Discovery comparison

- Bonjour: **Observed** mutual physical discovery without manual IP entry. Exact discovery latency, stale services, and duplicate behavior were not recorded.
- MultipeerConnectivity: **Observed** mutual physical discovery and connection. Exact discovery latency, stale peers, and duplicate behavior were not recorded.
- UDP multicast: **Code-inspected** implementation logs received datagrams without creating peers or trust. Delivery and entitlement behavior are **Not tested**.

Bonjour and MPC both satisfy the baseline physical discovery requirement on the tested ordinary Wi-Fi.

## 7. Session comparison

- Bonjour/Network: **Observed** connected session and successful ping/pong with both the iPhone and Mac as originators. Displayed RTT samples include 25.0 ms, 43.8 ms, 51.4 ms, and 250.5 ms.
- MPC: **Observed** connected session and a complete iPhone-originated ping/Mac pong round trip at 34.5 ms. A separate Mac-originated MPC round trip has not been captured. Framework encryption still does not prove user pairing or Holon identity.
- UDP: **Code-inspected** intentionally has no reliable session.

Full two-origin bidirectional exchange is proven for Bonjour/Network on the tested device pair and Wi-Fi.

## 8. Lifecycle comparison

**Observed:** manual Bonjour disconnect, reconnect, and post-reconnect ping/pong succeeded. An earlier automatic reconnect sequence was also captured. Background, lock, Wi-Fi change, sleep/wake, and deliberate app restart behavior remain untested. MPC requires manual reinvitation in this spike.

## 9. Diagnostic-quality comparison

**Code-inspected:** common events include role, experiment, category, state, peer/message references, optional duration/error fields, and human-readable detail. Framework waiting/failure, decode rejection, discovery, invitation, connection, disconnection, message send/receive, and lifecycle callbacks are represented.

**Observed:** diagnostics explained discovery, connection, send, receive, response, RTT, disconnect, reconnect, the original `ECANCELED`, and the corrected successful paths. Error domain/code display and immediate send-failure handling were physically exercised.

## 10. Security implications

- **Code-inspected:** UI and events label the experiment untrusted.
- **Code-inspected:** service names, addresses, and `MCPeerID` values are ephemeral references, not identities.
- **Code-inspected:** only ping/pong messages are decoded. MPC streams and resource transfers are rejected. No file, shell, arbitrary command, model, cloud, relay, payment, reputation, or Holonia propagation capability exists.
- **Code-inspected:** MPC invitation acceptance is automatic for experimental convenience and is explicitly logged as not pairing or authorization. Production pairing remains open.
- UDP multicast entitlement/provisioning and its network exposure require physical evaluation.

## 11. Known failures and blockers

- The shared iOS session-control row previously triggered Send and Disconnect together under automatic SwiftUI button styling. Explicit button styles resolved the defect in physical Bonjour and MPC retests.
- Exact Wi-Fi/router metadata and discovery/connect timings were not recorded.
- iOS multicast commonly requires a separately approved/provisioned entitlement; this spike does not claim it.

## 12. Recommendation

**Provisional recommendation: Bonjour + Network.framework leads into NB-1.** It is observed with both devices originating successful ping/pong and with a controlled disconnect/reconnect/post-reconnect exchange. It also exposes explicit endpoint, connection, error, and reconnect state useful for future pairing and Host policy. MPC discovered, connected, and completed an iPhone-originated round trip with less implementation code, so it remains a viable comparison candidate. Keep the ADR provisional until at least one additional network environment and basic app lifecycle cases are tested.

## 13. Remaining uncertainty

Repeated-run reliability, Local Network permission onboarding/denial, stale-peer behavior, background/lock behavior, sleep/wake, Wi-Fi changes, hotspot/restrictive networks, UDP entitlement/delivery, and Mac-originated MPC round trip remain uncertain. Production pairing, identity, authentication, revocation, background availability, and final architecture remain deliberately open.

The non-blocking physical and network evidence is tracked as an explicit checkbox backlog in [`deferred-validation-todo.md`](deferred-validation-todo.md). These unchecked items do not block the `NB-1 → NB-5` implementation mainline and must not be reported as tested.

## 14. Proposed next step

Begin NB-1 as a narrow node-discovery phase using the provisional Bonjour + Network.framework stack: define the minimal untrusted peer model, peer found/lost/dedup behavior, Local Network permission UX, and late-start/app-restart behavior. Continue the remaining NB-0 network/lifecycle matrix as evidence work without expanding into pairing or production identity yet.
