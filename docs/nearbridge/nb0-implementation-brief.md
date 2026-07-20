
# NearBridge NB-0 Implementation Brief

## 1. Purpose

NB-0 is the first implementation step for NearBridge.

It answers one technical question:

> Which native Apple technology combination can reliably support local discovery and a bidirectional small-message session between an iPhone and a Mac mini?

The first device combination is fixed:

```text
iPhone / iOS
↔
Mac mini / macOS
```

Both applications are launched by the user. Availability follows the application lifecycle.

NB-0 is an experimental technology spike. It does not define the production pairing protocol, permanent device identity, public Holonia protocol, or final package architecture.

## 2. Relationship to NearBridge v0

NearBridge v0 will eventually provide:

1. local peer discovery;
2. user-approved pairing;
3. peer authentication;
4. a bidirectional session;
5. small-message exchange;
6. disconnect, reconnect, and revocation behavior;
7. diagnostic and audit events;
8. one registered local-capability invocation.

NB-0 validates only the technologies required to support discovery and sessions.

```text
NB-0
    discovery and session technology evidence

Later phases
    pairing
    authenticated identity
    protected Holonia messages
    revocation
    connection request
    registered capability invocation
```

Success in NB-0 does not imply that a discovered device is trusted or authorized.

## 3. Objectives

NB-0 should determine whether an iPhone and a Mac mini can:

- advertise their availability on a local network;
- discover one another without manual IP entry;
- establish a bidirectional experimental session;
- exchange small ping and pong messages;
- detect disconnects;
- attempt reconnection;
- emit useful structured diagnostic events;
- behave predictably under common application and network lifecycle changes.

The implementation should collect enough evidence to recommend a discovery and session technology combination for the next NearBridge phase.

## 4. Environment inventory

Before implementation, record the actual development and test environment.

| Item | Value |
| --- | --- |
| Mac mini model | TBD |
| Mac mini chip | TBD |
| macOS version | TBD |
| iPhone model | TBD |
| iOS version | TBD |
| Xcode version | TBD |
| Swift version | TBD |
| Apple Developer signing available | TBD |
| Physical iPhone connected to development Mac | TBD |
| Home or office Wi-Fi available | TBD |
| Personal Hotspot testing available | TBD |
| Restrictive or guest Wi-Fi available | TBD |

If some information is unavailable, implementation may continue where possible, but the missing information must be reported.

Simulator results must not be presented as physical-device network validation.

## 5. Working implementation choices

The following are reversible working choices for the spike, not permanent compatibility commitments:

- use Swift for the iOS and macOS applications;
- use SwiftUI for the minimal experiment interface;
- prefer Apple-provided networking and cryptographic frameworks;
- avoid third-party runtime dependencies;
- use a small shared Swift module for experiment messages and diagnostics;
- keep transport experiments replaceable;
- use versioned JSON with `Codable` for experimental ping and pong messages unless a tested framework requires another representation.

These choices may be changed if implementation evidence demonstrates a concrete problem.

Any change should be explained in the NB-0 results document.

## 6. Technical experiments

NB-0 evaluates three candidates.

The experiments should remain small. They are not three production implementations.

### 6.1 Experiment A — Bonjour and Network.framework

Evaluate:

- Bonjour or mDNS service advertisement;
- Bonjour service browsing;
- endpoint resolution;
- `Network.framework` for a reliable bidirectional session;
- connection state reporting;
- ping and pong exchange;
- disconnect detection;
- reconnection behavior.

The experiment should determine:

- how quickly peers discover one another;
- whether stale services remain visible;
- whether service identity survives temporary network changes;
- how connection failures are reported;
- whether one transport session can be reused for several messages;
- what additional work would be required for authenticated sessions.

Discovery metadata must remain minimal and must not contain sensitive user information.

### 6.2 Experiment B — MultipeerConnectivity

Evaluate:

- peer advertisement;
- peer browsing;
- invitation and session establishment;
- ping and pong exchange;
- connection state changes;
- reconnection behavior;
- behavior across iOS and macOS;
- visibility into errors and diagnostics.

The experiment should determine:

- whether MultipeerConnectivity provides a simpler implementation;
- whether discovery is sufficiently predictable;
- whether session lifecycle behavior is observable enough for NearBridge;
- whether the framework hides information required for debugging or future policy enforcement;
- whether its platform and topology assumptions fit the iPhone–Mac mini path.

NB-0 must not treat MultipeerConnectivity encryption as proof of NearBridge user pairing or Holon identity.

### 6.3 Experiment C — UDP multicast or broadcast probe

Evaluate UDP only as a discovery and network-behavior probe.

The probe should determine:

- whether multicast or broadcast packets can be sent and received;
- how iOS local-network permission affects the result;
- whether packets are delivered on the available Wi-Fi networks;
- whether packet duplication or loss is visible;
- whether the application receives packets after lifecycle transitions;
- whether Personal Hotspot changes the behavior.

UDP is not assumed to be the final reliable session transport.

The probe must not:

- execute actions based only on a UDP packet;
- transmit sensitive content;
- interpret a source IP address as identity;
- implement open-network Holonia propagation;
- forward received packets to other peers.

## 7. Minimal project structure

Keep the spike structure small and reversible.

A suitable initial shape is:

```text
NearBridge
├── NearBridgeIOS
│   ├── Experiment selection
│   ├── Peer discovery view
│   ├── Session controls
│   └── Diagnostic event view
├── NearBridgeMac
│   ├── Experiment selection
│   ├── Peer discovery view
│   ├── Session controls
│   └── Diagnostic event view
└── NearBridgeShared
    ├── ExperimentMessage
    ├── ExperimentEvent
    ├── TransportState
    └── Diagnostic formatting
```

This may be one Xcode project with separate iOS and macOS targets and one small shared module.

Do not create a large package hierarchy during NB-0.

Transport implementations may remain in their corresponding application targets until the spike produces evidence for a final direction.

Shared code should contain only behavior that is genuinely common to both applications.

## 8. Experimental message format

NB-0 uses only non-sensitive test messages.

The minimum experimental message is:

```text
ExperimentMessage
├── schemaVersion
├── messageID
├── messageType
├── sentAt
├── correlationID
└── payload
```

Required fields:

| Field | Meaning |
| --- | --- |
| `schemaVersion` | Experimental message schema version |
| `messageID` | Unique identifier for this message |
| `messageType` | `ping` or `pong` |
| `sentAt` | Sender timestamp |
| `correlationID` | Connects a pong to its ping |
| `payload` | Small non-sensitive test value |

Example:

```json
{
  "schemaVersion": 1,
  "messageID": "B515CF03-6DBF-4361-9E7E-873D174CFD47",
  "messageType": "ping",
  "sentAt": "2026-07-20T18:30:00Z",
  "correlationID": "B515CF03-6DBF-4361-9E7E-873D174CFD47",
  "payload": {
    "sequence": 1
  }
}
```

The receiver should return a pong using the same `correlationID`.

This is an experiment schema. It is not the Holonia protocol and creates no external compatibility commitment.

## 9. Transport abstraction

The spike may use a small internal abstraction to prevent the user interface from depending directly on one experiment.

It should remain narrower than a production networking framework.

A conceptual interface is:

```swift
protocol ExperimentTransport {
    var events: AsyncStream<ExperimentEvent> { get }

    func start() async throws
    func stop() async
    func connect(to peer: ExperimentPeer) async throws
    func disconnect() async
    func send(_ message: ExperimentMessage) async throws
}
```

The exact Swift API may change when implementation requirements are understood.

Do not design production identity, authorization, relay, routing, engagement, or delivery semantics into this interface.

## 10. Application interface

Both applications should provide a minimal experiment interface.

The interface should show:

- selected experiment;
- local service or peer status;
- discovered peers;
- current connection state;
- a connect or invite action when required;
- a disconnect action;
- a send-ping action;
- last received message;
- ping round-trip time when available;
- structured diagnostic events;
- a clear indication that NB-0 is an untrusted experiment.

The interface does not need production visual design.

Clarity and diagnostics are more important than appearance.

## 11. State reporting

At minimum, report these conceptual states.

### 11.1 Discovery state

```text
stopped
starting
advertising
browsing
peerDiscovered
peerLost
failed
```

### 11.2 Session state

```text
idle
connecting
connected
disconnecting
disconnected
reconnecting
failed
```

### 11.3 Message state

```text
created
sending
sent
received
responded
timedOut
failed
```

Framework-specific states may be included, but the application should also expose a small common state vocabulary for comparison.

## 12. Diagnostics

Diagnostics are a first-class NB-0 deliverable.

Each diagnostic event should contain enough information to reconstruct what happened without exposing secrets.

Recommended fields:

```text
ExperimentEvent
├── eventID
├── timestamp
├── deviceRole
├── experiment
├── category
├── state
├── peerReference
├── messageReference
├── duration
├── errorDomain
├── errorCode
└── humanReadableDetail
```

Useful event categories include:

- application lifecycle;
- local-network permission;
- advertisement;
- browsing;
- peer discovered;
- peer lost;
- invitation;
- connection;
- disconnection;
- reconnection;
- message send;
- message receive;
- timeout;
- framework error;
- decoding error.

Diagnostics may be shown in the interface and written to a local development log.

Do not log:

- cryptographic keys;
- signing credentials;
- personal user information;
- sensitive network credentials;
- protected Holonia message content.

## 13. Security boundaries

NB-0 does not implement production trust, but it must preserve the following boundaries:

- discovery is not authentication;
- a service name is not a stable identity;
- an IP address is not a stable identity;
- a framework peer identifier is not automatically a Holon identity;
- encryption supplied by a transport does not prove user-approved pairing;
- only ping and pong test messages may be exchanged;
- no file transfer is allowed;
- no arbitrary commands are allowed;
- no shell execution is allowed;
- no local model or cloud model invocation is allowed;
- no sensitive Holonia data is allowed;
- no device should expose general remote-control functionality.

Any temporary identifier generated by NB-0 must be clearly labeled experimental.

## 14. Physical-device test matrix

Run the selected experiments against as much of the following matrix as the available environment permits.

| Test | Expected observation |
| --- | --- |
| Both apps on the same normal Wi-Fi | Discovery and ping/pong behavior |
| iPhone local-network permission not yet requested | Permission onboarding behavior |
| User grants local-network permission | Discovery becomes available |
| User denies local-network permission | Clear error and recovery instructions |
| One app starts before the other | Late peer discovery |
| Mac app restarts | Peer loss and rediscovery |
| iPhone app restarts | Peer loss and rediscovery |
| iPhone enters background briefly | Session and discovery state changes |
| iPhone returns to foreground | Rediscovery or reconnection behavior |
| Mac sleeps and wakes | Disconnect and recovery behavior |
| Wi-Fi is disabled and re-enabled | Failure and reconnection behavior |
| Device changes Wi-Fi network | Stale-peer and recovery behavior |
| Personal Hotspot | Discovery and session behavior |
| Restrictive or guest Wi-Fi | Failure mode and diagnostic quality |
| Several ping messages are sent | Ordering, loss, duplication and round-trip time |
| Same service is discovered repeatedly | Duplicate handling |
| Malformed experimental message is received | Safe decoding failure |
| Session is manually disconnected | Both sides report a consistent state |

Every result must identify:

- device model;
- operating-system version;
- experiment used;
- network environment;
- whether the result was observed physically or simulated;
- relevant diagnostic events.

## 15. Measurements

Where practical, record:

- time from application start to first peer discovery;
- time from connect request to connected state;
- ping round-trip time;
- number of duplicate discovery events;
- number of failed connection attempts;
- time required to rediscover a restarted peer;
- time required to reconnect after temporary network loss;
- whether manual user action was required;
- whether the framework produced a useful error.

Performance measurements do not need benchmarking precision. Their purpose is to compare the candidate technologies and expose lifecycle problems.

## 16. Automated tests

Add unit tests for shared behavior that does not require physical networking.

At minimum, test:

- ping encoding and decoding;
- pong encoding and decoding;
- schema-version rejection or handling;
- malformed-message rejection;
- correlation between ping and pong;
- diagnostic event creation;
- state transition rules where implemented;
- duplicate message identifier handling if the spike tracks received messages.

Do not create mocks that falsely imply physical discovery has been validated.

Framework-specific integration tests may be added when they provide useful evidence and run reliably.

## 17. Required deliverables

NB-0 should produce:

1. a buildable iOS experiment application;
2. a buildable macOS experiment application;
3. a minimal shared experiment module;
4. Bonjour and Network.framework experiment code;
5. MultipeerConnectivity experiment code;
6. a UDP multicast or broadcast probe where supported;
7. ping and pong exchange;
8. structured diagnostic events;
9. shared unit tests;
10. a physical-device test runbook;
11. an NB-0 results document;
12. an architecture decision record only when sufficient evidence exists.

Required documentation:

```text
docs/nearbridge/
├── nb0-implementation-brief.md
├── nb0-test-runbook.md
├── nb0-results.md
└── adr/
    └── 0001-discovery-and-session-stack.md
```

The ADR should not be created as an accepted decision before evidence is available. A draft may be used to organize the comparison.

## 18. NB-0 results document

`nb0-results.md` should contain:

```text
1. Environment
2. Implemented experiments
3. Tests actually run
4. Physical-device results
5. Simulator-only results
6. Discovery comparison
7. Session comparison
8. Lifecycle comparison
9. Diagnostic-quality comparison
10. Security implications
11. Known failures
12. Recommendation
13. Remaining uncertainty
14. Proposed next step
```

Every claim must be classified as one of:

- **Observed** — reproduced on the stated physical devices;
- **Simulated** — observed only in a simulator;
- **Code-inspected** — inferred from implementation or API behavior;
- **Not tested** — still requires evidence.

## 19. Decision criteria

A recommended discovery and session stack should be selected using these priorities:

1. reliable iPhone–Mac mini behavior on physical devices;
2. clear application lifecycle behavior;
3. explicit control over connection establishment;
4. ability to add user-approved pairing and authentication later;
5. useful error reporting and diagnostics;
6. no manual IP entry;
7. low implementation and maintenance complexity;
8. minimal public discovery metadata;
9. compatibility with future Host authorization;
10. acceptable behavior on Personal Hotspot and restrictive networks.

Developer convenience alone is not sufficient reason to choose a technology.

If no candidate satisfies the criteria, the result should document the failure instead of forcing a decision.

## 20. Exit criteria

NB-0 is complete when:

- both application targets build in the available development environment;
- at least one experiment supports discovery between a physical iPhone and Mac mini;
- at least one experiment supports bidirectional ping and pong exchange;
- disconnect behavior is observable;
- at least one reconnection path has been tested;
- local-network permission behavior is documented;
- no manual IP address is required for the successful path;
- diagnostic events explain the successful path and common failures;
- simulator and physical-device evidence are clearly separated;
- the test runbook can be followed by another developer;
- the results document compares the candidates;
- the evidence either supports a recommended stack or clearly explains why the decision remains open.

If Codex cannot access physical devices, it may complete the implementation and test runbook, but NB-0 must remain incomplete until the physical tests are performed.

## 21. Non-goals

NB-0 must not implement:

- a production pairing ceremony;
- permanent device identity;
- Primary Holon Accounts;
- account recovery;
- key rotation;
- shared trust domains;
- public Holonia identities;
- capability broadcasting beyond the local experiment;
- bounded multi-hop propagation;
- Reply Routes;
- private Holonia sessions;
- engagements;
- delivery and acceptance;
- reputation;
- payment;
- blockchain;
- cloud infrastructure;
- exo integration;
- distributed model inference;
- local model selection;
- third-party Primary Holon implementations;
- arbitrary file access;
- arbitrary command execution;
- a background Host daemon;
- a production protocol compatibility commitment.

## 22. Implementation conduct

Before editing code, the implementing agent should:

1. read the canonical project documents;
2. inspect the available repository and Apple toolchain;
3. record missing environment information;
4. propose a small implementation plan;
5. identify assumptions that remain reversible;
6. report any conflict with confirmed design decisions.

While implementing, the agent should:

- keep changes limited to NB-0;
- preserve useful diagnostics;
- build and test incrementally;
- avoid speculative abstractions;
- avoid unrelated Holonia components;
- document deviations from this brief.

Before completing the task, the agent should:

- build both targets where the environment permits;
- run shared unit tests;
- review the changes for unsafe capability exposure;
- list commands and checks actually run;
- distinguish untested behavior from failures;
- provide exact physical-device test instructions;
- identify the smallest next step.

## 23. Expected next phase

NB-0 selects or narrows the discovery and session technologies.

The next phase will use that evidence to design:

```text
explicit user pairing
→ device authentication
→ protected small-message session
→ revocation
```

NB-0 must leave enough flexibility for that design and must not silently decide it in advance.
