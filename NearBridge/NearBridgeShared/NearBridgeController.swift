import Combine
import Foundation
import os

@MainActor
public final class NearBridgeController: ObservableObject {
    @Published public private(set) var peers: [NearBridgePeer] = []
    @Published public private(set) var discoveryState: DiscoveryState = .stopped
    @Published public private(set) var sessionState: SessionState = .idle
    @Published public private(set) var localNetworkAccess: LocalNetworkAccessState = .unknown
    @Published public private(set) var events: [NearBridgeEvent] = []
    @Published public private(set) var isRunning = false
    @Published public private(set) var localIdentity: NearBridgeNodeIdentity?
    @Published public private(set) var pairedNodes: [PairedNodeRecord] = []
    @Published public private(set) var pendingPairing: PendingPairing?
    @Published public private(set) var identityIssue: String?

    public let role: DeviceRole
    public let phase = NearBridgeBuild.phase

    private var transport: BonjourNetworkTransport?
    private var registry = NearBridgeDiscoveryRegistry()
    private let identityManager: HostIdentityManager?
    private let pairingStore = KeychainPairingRecordStore()
    private var trustRegistry = NearBridgeTrustRegistry()
    private var pairingMachine = NearBridgePairingStateMachine()
    private var localHello: PairingHello?
    private var remoteHello: PairingHello?
    private var transcriptHash: Data?
    private var activePeerReference: String?
    private let logger = Logger(subsystem: "org.holonia.nearbridge.v0", category: "pairing")

    public init(role: DeviceRole) {
        self.role = role
        do {
            let identity = try HostIdentityManager.loadOrCreate()
            identityManager = identity
            localIdentity = identity.identity
        } catch {
            identityManager = nil
            identityIssue = error.localizedDescription
        }
        do {
            trustRegistry = try pairingStore.load()
            pairedNodes = trustRegistry.records
        } catch {
            identityIssue = [identityIssue, "Could not load pairings: \(error.localizedDescription)"].compactMap { $0 }.joined(separator: " · ")
        }
    }

    public func start() {
        guard !isRunning else { return }
        let transport = BonjourNetworkTransport(role: role, allowsSessions: phase.allowsTransportSessions)
        bind(transport)
        self.transport = transport
        isRunning = true
        discoveryState = .starting
        record(category: .applicationLifecycle, state: "started", detail: "User launched NearBridge discovery and pairing")
        if let localIdentity {
            record(category: .identity, state: "hostKeyReady", peer: localIdentity.nodeID, detail: "Host-managed stable identity \(localIdentity.fingerprint) is ready")
        } else {
            record(category: .identity, state: "unavailable", error: nil, detail: identityIssue ?? "Host identity unavailable")
        }
        transport.start()
    }

    public func stop() {
        transport?.stop()
        transport = nil
        isRunning = false
        for change in registry.removeAll() { record(change) }
        peers = []
        discoveryState = .stopped
        sessionState = .idle
        resetHandshake()
        record(category: .applicationLifecycle, state: "stopped", detail: "NearBridge stopped")
    }

    public func connect(to peer: NearBridgePeer) {
        guard identityManager != nil else {
            record(category: .identity, state: "unavailable", peer: peer.id, detail: identityIssue ?? "Host identity unavailable")
            return
        }
        guard ![.connecting, .connected, .reconnecting].contains(sessionState) else {
            record(category: .connection, state: "alreadyActive", peer: peer.id, detail: "Only one pairing session is allowed")
            return
        }
        activePeerReference = peer.id
        sessionState = .connecting
        record(category: .connection, state: "connecting", peer: peer.id, detail: "Opening an untrusted pairing channel")
        transport?.connect(to: peer.id)
    }

    public func approvePairing() {
        guard pairingMachine.hasVerifiedHello, !pairingMachine.localApproved else { return }
        pairingMachine.approveLocally()
        record(category: .pairing, state: "locallyApproved", peer: remoteHello?.nodeID, detail: "User approved the displayed verification code")
        sendConfirmation()
        publishPendingPairing()
        establishPairingIfComplete()
    }

    public func rejectPairing() {
        guard pendingPairing != nil else { return }
        pairingMachine.reject()
        publishPendingPairing()
        record(category: .pairing, state: "rejected", peer: remoteHello?.nodeID, detail: "User rejected the pairing request")
        transport?.disconnect()
    }

    public func disconnect() {
        transport?.disconnect()
    }

    public func revoke(_ pairedNode: PairedNodeRecord) {
        guard trustRegistry.revoke(nodeID: pairedNode.nodeID) != nil else { return }
        persistPairings()
        pairedNodes = trustRegistry.records
        record(category: .revocation, state: "revoked", peer: pairedNode.nodeID, detail: "Local trust for \(pairedNode.displayName) was revoked")
        if remoteHello?.nodeID == pairedNode.nodeID { transport?.disconnect() }
    }

    public func recordLifecycle(_ state: String) {
        record(category: .applicationLifecycle, state: state, detail: "Application scene is \(state)")
    }

    private func bind(_ transport: BonjourNetworkTransport) {
        transport.onPeersChanged = { [weak self] observations in
            DispatchQueue.main.async {
                guard let self else { return }
                let changes = self.registry.reconcile(observations)
                self.peers = self.registry.peers
                self.discoveryState = self.peers.isEmpty ? .browsing : .peerDiscovered
                for change in changes { self.record(change) }
            }
        }
        transport.onData = { [weak self] data, peer in
            DispatchQueue.main.async { self?.receive(data, peer: peer) }
        }
        transport.onEvent = { [weak self] event in
            DispatchQueue.main.async { self?.handle(event) }
        }
    }

    private func handle(_ transportEvent: TransportEvent) {
        switch transportEvent {
        case .session(let state, let peer):
            sessionState = state
            activePeerReference = peer ?? activePeerReference
            record(category: .connection, state: state.rawValue, peer: peer, detail: "Pairing channel is \(state.rawValue)")
            if state == .connected { beginHandshakeIfNeeded() }
            if state == .disconnected || state == .failed { resetHandshake() }
        case .diagnostic(let category, let state, let peer, let detail, let error):
            switch category {
            case .advertisement:
                localNetworkAccess = .available
                discoveryState = .advertising
                record(category: .discovery, state: state, peer: peer, error: error, detail: detail)
            case .browsing:
                localNetworkAccess = .available
                discoveryState = peers.isEmpty ? .browsing : .peerDiscovered
                record(category: .discovery, state: state, peer: peer, error: error, detail: detail)
            case .localNetworkPermission:
                localNetworkAccess = .attentionRequired
                record(category: .localNetworkPermission, state: state, peer: peer, error: error, detail: detail)
            case .frameworkError, .decodingError:
                if ["listenerFailed", "browserFailed", "failed"].contains(state) { discoveryState = .failed }
                record(category: .frameworkError, state: state, peer: peer, error: error, detail: detail)
            case .peerDiscovered, .peerLost:
                break
            default:
                record(category: .connection, state: state, peer: peer, error: error, detail: detail)
            }
        }
    }

    private func beginHandshakeIfNeeded() {
        guard localHello == nil, let identityManager else { return }
        do {
            let nonce = Data((0..<32).map { _ in UInt8.random(in: .min ... .max) })
            let hello = try PairingProtocol.makeHello(
                identityManager: identityManager,
                role: role,
                displayName: "NearBridge-\(role.rawValue)",
                nonce: nonce
            )
            localHello = hello
            let envelope = PairingEnvelope(kind: .hello, hello: hello)
            transport?.send(try PairingProtocol.encode(envelope))
            record(category: .pairing, state: "helloSent", peer: activePeerReference, detail: "Sent signed identity proof on the untrusted channel")
        } catch {
            record(category: .pairing, state: "helloFailed", peer: activePeerReference, error: error, detail: error.localizedDescription)
            transport?.disconnect()
        }
    }

    private func receive(_ data: Data, peer: String?) {
        do {
            let envelope = try PairingProtocol.decode(data)
            switch envelope.kind {
            case .hello:
                guard let hello = envelope.hello else { throw PairingProtocolError.invalidPayload }
                try receive(hello, peer: peer)
            case .confirmation:
                guard let confirmation = envelope.confirmation else { throw PairingProtocolError.invalidPayload }
                try receive(confirmation, peer: peer)
            }
        } catch {
            record(category: .pairing, state: "messageRejected", peer: peer, error: error, detail: error.localizedDescription)
            transport?.disconnect()
        }
    }

    private func receive(_ hello: PairingHello, peer: String?) throws {
        try PairingProtocol.verify(hello)
        if let existing = pairedNodes.first(where: { $0.nodeID == hello.nodeID }), existing.publicKeyBase64 != hello.publicKeyBase64 {
            throw PairingProtocolError.identityMismatch
        }
        beginHandshakeIfNeeded()
        guard let localHello else { throw PairingProtocolError.invalidPayload }
        remoteHello = hello
        transcriptHash = try PairingProtocol.transcriptHash(local: localHello, remote: hello)
        pairingMachine.receiveVerifiedHello()
        let known = trustRegistry.contains(nodeID: hello.nodeID)
        record(
            category: .pairing,
            state: known ? "knownIdentityProved" : "approvalRequired",
            peer: hello.nodeID,
            detail: known ? "A previously paired public key presented a fresh signed hello" : "A stranger proved key possession but remains untrusted until user confirmation"
        )
        if known {
            pairingMachine.approveLocally()
            sendConfirmation()
        }
        publishPendingPairing()
        establishPairingIfComplete()
    }

    private func receive(_ confirmation: PairingConfirmation, peer: String?) throws {
        guard let transcriptHash, let remoteHello else { throw PairingProtocolError.transcriptMismatch }
        try PairingProtocol.verify(confirmation, expectedTranscriptHash: transcriptHash, peerHello: remoteHello)
        pairingMachine.receiveVerifiedConfirmation()
        record(category: .pairing, state: "remoteConfirmed", peer: peer, detail: "Peer signed the current pairing transcript")
        publishPendingPairing()
        establishPairingIfComplete()
    }

    private func sendConfirmation() {
        guard let identityManager, let transcriptHash else { return }
        do {
            let confirmation = try PairingProtocol.makeConfirmation(identityManager: identityManager, transcriptHash: transcriptHash)
            transport?.send(try PairingProtocol.encode(.init(kind: .confirmation, confirmation: confirmation)))
            record(category: .pairing, state: "confirmationSent", peer: remoteHello?.nodeID, detail: "Sent signed confirmation for this pairing transcript")
        } catch {
            record(category: .pairing, state: "confirmationFailed", peer: remoteHello?.nodeID, error: error, detail: error.localizedDescription)
        }
    }

    private func establishPairingIfComplete() {
        guard pairingMachine.state == .established, let remoteHello else { return }
        if !trustRegistry.contains(nodeID: remoteHello.nodeID) {
            trustRegistry.trust(PairedNodeRecord(
                nodeID: remoteHello.nodeID,
                displayName: remoteHello.displayName,
                role: remoteHello.role,
                publicKeyBase64: remoteHello.publicKeyBase64
            ))
            persistPairings()
            pairedNodes = trustRegistry.records
        }
        publishPendingPairing()
        record(category: .pairing, state: "paired", peer: remoteHello.nodeID, detail: "Mutual user-confirmed pairing stored by the Host")
    }

    private func publishPendingPairing() {
        guard let remoteHello, let transcriptHash else {
            pendingPairing = nil
            return
        }
        pendingPairing = PendingPairing(
            nodeID: remoteHello.nodeID,
            displayName: remoteHello.displayName,
            role: remoteHello.role,
            fingerprint: String(remoteHello.nodeID.prefix(12)).uppercased(),
            verificationCode: PairingProtocol.pairingCode(transcriptHash: transcriptHash),
            state: pairingMachine.state,
            isKnownPairing: trustRegistry.contains(nodeID: remoteHello.nodeID)
        )
    }

    private func persistPairings() {
        do {
            try pairingStore.save(trustRegistry)
        } catch {
            record(category: .frameworkError, state: "pairingStoreFailed", error: error, detail: "Could not persist local pairing state")
        }
    }

    private func resetHandshake() {
        pairingMachine = NearBridgePairingStateMachine()
        localHello = nil
        remoteHello = nil
        transcriptHash = nil
        activePeerReference = nil
        pendingPairing = nil
    }

    private func record(_ change: NearBridgeDiscoveryChange) {
        switch change {
        case .found(let peer):
            record(category: .peerFound, state: "untrusted", peer: peer.id, detail: "Discovered \(peer.displayName); discovery is not authentication")
        case .lost(let peer):
            record(category: .peerLost, state: "lost", peer: peer.id, detail: "Lost \(peer.displayName)")
        }
    }

    private func record(
        category: NearBridgeEventCategory,
        state: String,
        peer: String? = nil,
        error: Error? = nil,
        detail: String
    ) {
        let event = NearBridgeEvent(
            phase: phase,
            deviceRole: role,
            category: category,
            state: state,
            peerReference: peer,
            error: error,
            humanReadableDetail: detail
        )
        events.insert(event, at: 0)
        if events.count > 300 { events.removeLast(events.count - 300) }
        logger.info("\(event.compactDescription, privacy: .public)")
    }
}
