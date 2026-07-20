# NearBridge NB-0 Physical-Device Test Runbook

This runbook validates an untrusted transport experiment between a user-launched iPhone app and a user-launched Mac app. Discovery is not authentication. Use only the built-in non-sensitive ping/pong payload.

## 1. Record the test environment

Before each run, copy this table into the results notes and fill every field. Do not infer missing values.

| Field | Value |
| --- | --- |
| Date and timezone | |
| Tester | |
| Mac mini model/chip | |
| macOS version | |
| iPhone model | |
| iOS version | |
| Xcode/Swift version | |
| Experiment candidate | |
| Network/router or hotspot | |
| Local Network permission state | not requested / granted / denied |
| Physical or simulated | physical |

## 2. Prepare and build

1. Open `NearBridge/NearBridge.xcodeproj` in Xcode.
2. Select a Development Team for `NearBridgeIOS` and `NearBridgeMac`. Keep the bundle identifiers unique if Xcode requires it.
3. Connect and trust the iPhone, enable Developer Mode if requested, and select it as the `NearBridgeIOS` run destination.
4. Run `NearBridgeMac` on the Mac mini and `NearBridgeIOS` on the physical iPhone.
5. Keep both apps visible for the baseline. Availability follows app lifecycle; there is no background daemon.
6. In Console.app, start a log stream filtered by subsystem `org.holonia.nearbridge.nb0`. The same structured summaries also appear in the app.

Command-line build checks, independent of device signing:

```sh
cd NearBridge
swift test
xcodebuild -project NearBridge.xcodeproj -scheme NearBridgeMac \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project NearBridge.xcodeproj -scheme NearBridgeIOS \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

The UDP multicast candidate can require Apple's multicast networking entitlement on physical iOS. This repository intentionally does not claim or provision that entitlement. If `waiting` or `groupFailed` appears, record it; do not alter the finding into a successful result. Request and provision the entitlement separately before repeating that candidate.

## 3. Baseline: Bonjour + Network.framework

1. Put both devices on the same ordinary Wi-Fi.
2. On each app, choose **Bonjour + Network.framework** and tap **Start**.
3. On first iPhone use, record when the Local Network prompt appears and grant it for the success path.
4. Verify each side reports advertisement/browsing diagnostics and shows the other ephemeral `NB0-*` service. Record startup-to-discovery time.
5. On one side only, tap **Connect** for the other peer. Record connect-to-connected time and both sides' connection events.
6. Tap **Send ping** on the iPhone. Verify the Mac receives ping and returns pong; record the iPhone RTT.
7. Tap **Send ping** on the Mac. Verify the inverse path and RTT.
8. Send at least ten more pings, alternating sides. Record failures, duplicates, ordering anomalies, and RTT range.
9. Tap **Disconnect**. Verify both sides show a disconnection state.
10. Reconnect once. Then stop and restart one app and record peer loss, rediscovery, and the two-second reconnect attempt behavior.

Pass evidence requires discovery without manual IP entry, connected events on both devices, and pong messages correlated to pings in both directions. A service label or IP is never authentication evidence.

## 4. Baseline: MultipeerConnectivity

1. Stop the previous experiment on both devices.
2. Choose **MultipeerConnectivity** and tap **Start** on both.
3. Record discovery time and the `MCPeerID (ephemeral)` peer rows.
4. Tap **Connect** on one side. The receiving spike accepts an NB-0 invitation automatically; record the explicit diagnostic warning. This is experiment session establishment, not user pairing.
5. Send ping from each side and confirm correlated pong and RTT.
6. Send ten alternating pings and record errors or duplicates.
7. Disconnect, restart each app in turn, and record loss/rediscovery. MPC has no explicit automatic reconnect policy in NB-0; reconnect manually and record that fact.

## 5. UDP multicast probe

1. Stop the previous experiment and choose **UDP multicast probe** on both devices.
2. Tap **Start**. Record `probeReady`, `waiting`, or `groupFailed` on each side.
3. Tap **Send ping** on each side. This sends one non-sensitive multicast datagram; it does not establish a session and does not trigger an automatic pong.
4. Record received datagrams, duplicates, loss, and whether the sender sees its own datagram.
5. Confirm **Connect** is unavailable and no action or forwarding occurs from a datagram.

## 6. Lifecycle and network matrix

Repeat the successful candidate and record timestamps/events for each case:

- start one app at least 30 seconds before the other;
- deny Local Network access, then restore it in Settings and restart the experiment;
- background the iPhone for 10 seconds, 60 seconds, and 5 minutes;
- lock and unlock the iPhone;
- quit/relaunch each app independently;
- sleep/wake the Mac;
- disable/re-enable Wi-Fi on each device;
- move both devices to Personal Hotspot;
- try guest/restrictive Wi-Fi, if available;
- inject a malformed message only with a purpose-built debug test build, never by adding general network or command input to the app.

For each case record discovery, connection, disconnect, reconnect, manual action, stale peer, and diagnostic quality. A failure with a useful diagnostic is still evidence.

## 7. Result classification and artifacts

Classify every claim as **Observed**, **Simulated**, **Code-inspected**, or **Not tested**. Save:

- the completed environment table;
- relevant structured event text from both devices;
- discovery/connect/reconnect timing notes;
- Local Network permission screenshots if useful;
- network topology description without passwords, private user data, or credentials;
- the exact Git commit and any temporary signing/entitlement changes.

Update `nb0-results.md`. Do not accept a discovery/session ADR until physical evidence compares the candidates.
