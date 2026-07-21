import Combine
import Foundation
import os

@MainActor
public final class NearBridgeController: ObservableObject {
    @Published public private(set) var peers: [NearBridgePeer] = []
    @Published public private(set) var discoveryState: DiscoveryState = .stopped
    @Published public private(set) var sessionState: SessionState = .idle
    @Published public private(set) var authenticatedSessionState: AuthenticatedSessionState = .idle
    @Published public private(set) var localNetworkAccess: LocalNetworkAccessState = .unknown
    @Published public private(set) var events: [NearBridgeEvent] = []
    @Published public private(set) var isRunning = false
    @Published public private(set) var localIdentity: NearBridgeNodeIdentity?
    @Published public private(set) var pairedNodes: [PairedNodeRecord] = []
    @Published public private(set) var pendingPairing: PendingPairing?
    @Published public private(set) var identityIssue: String?
    @Published public private(set) var lastSentMessage: NearBridgeReliableMessage?
    @Published public private(set) var lastReceivedMessage: NearBridgeReliableMessage?
    @Published public private(set) var roundTripMilliseconds: Double?
    @Published public private(set) var pendingPingCount = 0
    @Published public private(set) var contactWorkflowState: ContactWorkflowState = .idle
    @Published public private(set) var contactWorkflowSummary: String?
    @Published public private(set) var registeredCapabilities: [NearBridgeCapabilityDescriptor] = []
    @Published public private(set) var capabilityExecutionState: CapabilityExecutionState = .idle
    @Published public private(set) var lastCapabilityOutput: String?
    @Published public private(set) var availablePrimaryHolons: [PrimaryHolonDescriptor] = []
    @Published public private(set) var selectedPrimaryHolon: PrimaryHolonDescriptor?
    @Published public private(set) var openAIAPIKeyConfigured = false
    @Published public private(set) var openAICredentialIssue: String?
    @Published public private(set) var remotePrimaryHolonDisclosure: String?
    @Published public private(set) var lastExecutionReceipt: NearBridgeExecutionReceipt?

    public let role: DeviceRole
    public let phase = NearBridgeBuild.phase

    private var transport: BonjourNetworkTransport?
    private var registry = NearBridgeDiscoveryRegistry()
    private let identityManager: HostIdentityManager?
    private let pairingStore = KeychainPairingRecordStore()
    private var pairingStoreAvailable = true
    private var capabilityRegistry: NearBridgeCapabilityRegistry
    private let primaryHolonCatalog: PrimaryHolonCatalog
    private let primaryHolonSelectionStore: PrimaryHolonSelectionStore
    private let openAIAPIKeyStore: OpenAIAPIKeyStore
    private var trustRegistry = NearBridgeTrustRegistry()
    private var pairingMachine = NearBridgePairingStateMachine()
    private var localHello: PairingHello?
    private var remoteHello: PairingHello?
    private var transcriptHash: Data?
    private var activePeerReference: String?
    private var reliableValidator: ReliableMessageValidator?
    private var activeSessionID: String?
    private var pendingPings: [UUID: Date] = [:]
    private var pendingAcknowledgements: Set<UUID> = []
    private var sequence = 0
    private var contactWorkflow = ContactWorkflowStateMachine()
    private var contactRequestMessage: NearBridgeReliableMessage?
    private var capabilityResponseMessage: NearBridgeReliableMessage?
    private var contactAcceptanceMessage: NearBridgeReliableMessage?
    private var pendingCapabilityInvocation: NearBridgeReliableMessage?
    private var activeHostCapabilityInvocationID: UUID?
    private let logger = Logger(subsystem: "org.holonia.nearbridge.v0", category: "authenticated-session")

    public init(role: DeviceRole) {
        self.role = role
        let primaryHolonCatalog = PrimaryHolonCatalog.standard()
        let primaryHolonSelectionStore = PrimaryHolonSelectionStore()
        let openAIAPIKeyStore = OpenAIAPIKeyStore()
        self.primaryHolonCatalog = primaryHolonCatalog
        self.primaryHolonSelectionStore = primaryHolonSelectionStore
        self.openAIAPIKeyStore = openAIAPIKeyStore
        if role == .mac {
            let adapter = primaryHolonSelectionStore.load(catalog: primaryHolonCatalog)
            availablePrimaryHolons = primaryHolonCatalog.descriptors
            selectedPrimaryHolon = adapter.descriptor
            capabilityRegistry = .macNB6(adapter: adapter)
            do {
                openAIAPIKeyConfigured = try openAIAPIKeyStore.isConfigured()
            } catch {
                openAICredentialIssue = error.localizedDescription
            }
        } else {
            capabilityRegistry = .empty()
        }
        registeredCapabilities = capabilityRegistry.descriptors
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
            pairingStoreAvailable = false
            identityIssue = [identityIssue, "Could not load pairings: \(error.localizedDescription)"].compactMap { $0 }.joined(separator: " · ")
        }
    }

    public var primaryHolonSelectionLocked: Bool {
        [.connecting, .connected, .reconnecting].contains(sessionState) || authenticatedSessionState != .idle
    }

    public var reviewReadiness: [NearBridgeReadinessItem] {
        let selected = role == .mac ? selectedPrimaryHolon != nil : (remotePrimaryHolonDisclosure != nil || contactWorkflowState == .completed)
        let needsCredential = role == .mac && selectedPrimaryHolon?.implementationID == PrimaryHolonImplementationID.openAIModelOnly
        return NearBridgeReviewReadiness.items(for: NearBridgeReadinessContext(
            isRunning: isRunning,
            localNetworkAccess: localNetworkAccess,
            peerCount: peers.count,
            sessionState: sessionState,
            authenticationState: authenticatedSessionState,
            contactState: contactWorkflowState,
            capabilityState: capabilityExecutionState,
            primaryHolonSelected: selected,
            primaryHolonNeedsCredential: needsCredential,
            primaryHolonCredentialConfigured: openAIAPIKeyConfigured
        ))
    }

    public var reviewReadinessProgress: Double {
        NearBridgeReviewReadiness.progress(for: reviewReadiness)
    }

    public var nextRecommendedAction: String {
        NearBridgeReviewReadiness.nextAction(for: reviewReadiness)
    }

    public var sanitizedDiagnostics: String {
        NearBridgeDiagnosticExport.make(
            phase: phase,
            role: role,
            readiness: reviewReadiness,
            receipt: lastExecutionReceipt,
            events: events
        )
    }

    public var connectedPeerName: String? { remoteHello?.displayName }

    public var remoteFingerprint: String {
        guard let nodeID = remoteHello?.nodeID else { return "not-yet-authenticated" }
        return String(nodeID.prefix(12)).uppercased()
    }

    @discardableResult
    public func saveOpenAIAPIKey(_ value: String) -> Bool {
        guard role == .mac else { return false }
        guard capabilityExecutionState != .executing else {
            openAICredentialIssue = "Wait for the active Primary Holon request to finish before changing its credential"
            return false
        }
        do {
            try openAIAPIKeyStore.save(value)
            openAIAPIKeyConfigured = true
            openAICredentialIssue = nil
            record(category: .capability, state: "credentialStored", detail: "Mac Host stored an OpenAI API key in Keychain; the secret was not logged")
            return true
        } catch {
            openAICredentialIssue = error.localizedDescription
            record(category: .capability, state: "credentialRejected", error: error, detail: error.localizedDescription)
            return false
        }
    }

    public func removeOpenAIAPIKey() {
        guard role == .mac, capabilityExecutionState != .executing else { return }
        do {
            try openAIAPIKeyStore.remove()
            openAIAPIKeyConfigured = false
            openAICredentialIssue = nil
            record(category: .capability, state: "credentialRemoved", detail: "Mac Host removed the OpenAI API key from Keychain")
        } catch {
            openAICredentialIssue = error.localizedDescription
            record(category: .capability, state: "credentialRemovalFailed", error: error, detail: error.localizedDescription)
        }
    }

    public func selectPrimaryHolon(implementationID: String) {
        guard role == .mac else {
            record(category: .capability, state: "selectionRejected", detail: "Only the Mac Host selects its local Primary Holon implementation")
            return
        }
        guard !primaryHolonSelectionLocked else {
            record(category: .capability, state: "selectionLocked", detail: "Disconnect before changing the Primary Holon implementation")
            return
        }
        guard let adapter = primaryHolonCatalog.adapter(implementationID: implementationID) else {
            record(category: .capability, state: "selectionRejected", detail: "The requested Primary Holon adapter is not compiled into the Host allowlist")
            return
        }
        do {
            try primaryHolonSelectionStore.save(implementationID: implementationID, catalog: primaryHolonCatalog)
            selectedPrimaryHolon = adapter.descriptor
            capabilityRegistry = .macNB6(adapter: adapter)
            registeredCapabilities = capabilityRegistry.descriptors
            capabilityExecutionState = .idle
            lastCapabilityOutput = nil
            record(
                category: .capability,
                state: "primaryHolonSelected",
                detail: "Host selected \(adapter.descriptor.displayName) through \(adapter.descriptor.adapterLabel)"
            )
        } catch {
            record(category: .capability, state: "selectionRejected", error: error, detail: error.localizedDescription)
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
        guard pairingStoreAvailable else {
            record(category: .frameworkError, state: "pairingStoreUnavailable", peer: peer.id, detail: "Pairing is disabled because Host trust storage is unavailable")
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

    public func sendAuthenticatedPing() {
        guard
            authenticatedSessionState == .authenticated,
            let identityManager,
            let sessionID = activeSessionID
        else {
            record(category: .messageSend, state: "rejectedNotAuthenticated", detail: "A paired and authenticated session is required")
            return
        }
        sequence += 1
        do {
            let ping = try ReliableMessageCodec.makePing(
                sequence: sequence,
                sessionID: sessionID,
                identityManager: identityManager
            )
            pendingPings[ping.messageID] = Date()
            pendingPingCount = pendingPings.count
            send(ping, state: "sending")
            schedulePingTimeout(ping)
        } catch {
            record(category: .messageSend, state: "signingFailed", error: error, detail: error.localizedDescription)
        }
    }

    public func startContactRequest() {
        guard role == .iPhone else {
            record(category: .workflow, state: "requestRejected", detail: "Primary Holon contact requests originate on the iPhone")
            return
        }
        guard contactWorkflow.state == .idle else { return }
        do {
            let context = try authenticatedContext()
            let message = try ReliableMessageCodec.makeContactRequest(
                sessionID: context.sessionID,
                identityManager: context.identity
            )
            try contactWorkflow.apply(message, direction: .sent)
            contactRequestMessage = message
            publishContactWorkflow()
            sendContactMessage(message, state: "requestSent")
        } catch {
            record(category: .workflow, state: "requestRejected", error: error, detail: error.localizedDescription)
        }
    }

    public func sendCapabilityResponse() {
        guard role == .mac else {
            record(category: .workflow, state: "responseRejected", detail: "Only the Mac Host can offer the selected Primary Holon capability")
            return
        }
        guard contactWorkflow.state == .requestReceived, let request = contactRequestMessage else { return }
        do {
            guard let requestedID = request.payload.contact?.capabilityID,
                  registeredCapabilities.contains(where: { $0.capabilityID == requestedID }) else {
                throw CapabilityError.notRegistered
            }
            let context = try authenticatedContext()
            let message = try ReliableMessageCodec.makeCapabilityResponse(
                to: request,
                summary: "Host offers \(selectedPrimaryHolon?.displayName ?? "one selected Primary Holon") through a fixed HolonAdapter",
                sessionID: context.sessionID,
                identityManager: context.identity
            )
            try contactWorkflow.apply(message, direction: .sent)
            capabilityResponseMessage = message
            publishContactWorkflow()
            sendContactMessage(message, state: "capabilityResponseSent")
        } catch {
            record(category: .workflow, state: "responseRejected", error: error, detail: error.localizedDescription)
        }
    }

    public func acceptContact() {
        guard role == .iPhone else {
            record(category: .workflow, state: "acceptanceRejected", detail: "The iPhone requester must accept the Primary Holon contact")
            return
        }
        guard contactWorkflow.state == .responseReceived, let response = capabilityResponseMessage else { return }
        do {
            let context = try authenticatedContext()
            let message = try ReliableMessageCodec.makeContactAccepted(
                response: response,
                sessionID: context.sessionID,
                identityManager: context.identity
            )
            try contactWorkflow.apply(message, direction: .sent)
            contactAcceptanceMessage = message
            publishContactWorkflow()
            sendContactMessage(message, state: "contactAccepted")
        } catch {
            record(category: .workflow, state: "acceptanceRejected", error: error, detail: error.localizedDescription)
        }
    }

    public func completeContact() {
        guard role == .mac else {
            record(category: .workflow, state: "completionRejected", detail: "The Mac capability provider completes the Primary Holon contact")
            return
        }
        guard contactWorkflow.state == .acceptanceReceived, let acceptance = contactAcceptanceMessage else { return }
        do {
            let context = try authenticatedContext()
            let message = try ReliableMessageCodec.makeContactCompleted(
                acceptance: acceptance,
                sessionID: context.sessionID,
                identityManager: context.identity
            )
            try contactWorkflow.apply(message, direction: .sent)
            publishContactWorkflow()
            sendContactMessage(message, state: "completed")
        } catch {
            record(category: .workflow, state: "completionRejected", error: error, detail: error.localizedDescription)
        }
    }

    public func invokePrimaryHolon(input: String) {
        do {
            guard role == .iPhone else { throw CapabilityError.wrongRole }
            guard contactWorkflowState == .completed else { throw CapabilityError.workflowNotCompleted }
            let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { throw CapabilityError.invalidInput }
            guard normalized.count <= 1_200 else { throw CapabilityError.inputTooLarge }
            let context = try authenticatedContext()
            let message = try ReliableMessageCodec.makeCapabilityInvocation(
                input: normalized,
                capabilityID: contactWorkflow.capabilityID ?? ContactDemoCapability.defaultCapabilityID,
                sessionID: context.sessionID,
                identityManager: context.identity
            )
            _ = try ReliableMessageCodec.encode(message)
            pendingCapabilityInvocation = message
            capabilityExecutionState = .requestSent
            lastCapabilityOutput = nil
            lastExecutionReceipt = NearBridgeExecutionReceipt(
                invocationID: message.payload.capability?.invocationID ?? message.messageID,
                capabilityID: message.payload.capability?.capabilityID ?? ContactDemoCapability.defaultCapabilityID,
                providerLabel: remotePrimaryHolonDisclosure ?? "Authenticated Mac Primary Holon",
                peerFingerprint: remoteFingerprint,
                outcome: .requestSent,
                integrity: "Signed request bound to the fresh session"
            )
            sendCapabilityMessage(message, state: "invocationSent")
        } catch {
            capabilityExecutionState = .failed
            lastCapabilityOutput = error.localizedDescription
            record(category: .capability, state: "invocationRejected", error: error, detail: error.localizedDescription)
        }
    }

    public func revoke(_ pairedNode: PairedNodeRecord) {
        var updated = trustRegistry
        guard updated.revoke(nodeID: pairedNode.nodeID) != nil else { return }
        do {
            try pairingStore.save(updated)
            trustRegistry = updated
            pairedNodes = updated.records
            record(category: .revocation, state: "revoked", peer: pairedNode.nodeID, detail: "Local trust for \(pairedNode.displayName) was revoked and persisted")
            if remoteHello?.nodeID == pairedNode.nodeID { transport?.disconnect() }
        } catch {
            pairingStoreAvailable = false
            record(category: .revocation, state: "revocationFailed", peer: pairedNode.nodeID, error: error, detail: "Host trust storage failed; the pairing remains trusted")
        }
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
            if state == .connected {
                authenticatedSessionState = .pairing
                beginHandshakeIfNeeded()
            }
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
                if ["sendFailed", "sessionNotReady", "connectionFailed"].contains(state) {
                    authenticatedSessionState = .failed
                    pendingPings.removeAll()
                    pendingPingCount = 0
                }
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
            switch NearBridgeWireProtocol.name(in: data) {
            case PairingEnvelope.protocolName:
                guard authenticatedSessionState != .authenticated else {
                    throw ReliableMessageError.unsupportedProtocol
                }
                let envelope = try PairingProtocol.decode(data)
                switch envelope.kind {
                case .hello:
                    guard let hello = envelope.hello else { throw PairingProtocolError.invalidPayload }
                    try receive(hello, peer: peer)
                case .confirmation:
                    guard let confirmation = envelope.confirmation else { throw PairingProtocolError.invalidPayload }
                    try receive(confirmation, peer: peer)
                }
            case NearBridgeReliableMessage.protocolName:
                try receiveReliableMessage(ReliableMessageCodec.decode(data), peer: peer)
            default:
                throw ReliableMessageError.unsupportedProtocol
            }
        } catch {
            let category: NearBridgeEventCategory = authenticatedSessionState == .authenticated ? .messageReceive : .pairing
            record(category: category, state: "messageRejected", peer: peer, error: error, detail: error.localizedDescription)
            if authenticatedSessionState != .authenticated { transport?.disconnect() }
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
            var updated = trustRegistry
            updated.trust(PairedNodeRecord(
                nodeID: remoteHello.nodeID,
                displayName: remoteHello.displayName,
                role: remoteHello.role,
                publicKeyBase64: remoteHello.publicKeyBase64
            ))
            do {
                try pairingStore.save(updated)
                trustRegistry = updated
                pairedNodes = updated.records
            } catch {
                pairingStoreAvailable = false
                authenticatedSessionState = .failed
                record(category: .pairing, state: "pairingStoreFailed", peer: remoteHello.nodeID, error: error, detail: "Host trust storage failed; pairing was not established")
                transport?.disconnect()
                return
            }
        }
        publishPendingPairing()
        record(category: .pairing, state: "paired", peer: remoteHello.nodeID, detail: "Mutual user-confirmed pairing stored by the Host")
        configureAuthenticatedSession(remoteHello: remoteHello)
    }

    private func configureAuthenticatedSession(remoteHello: PairingHello) {
        guard let transcriptHash else { return }
        let sessionID = transcriptHash.base64EncodedString()
        activeSessionID = sessionID
        reliableValidator = ReliableMessageValidator(
            expectedSenderNodeID: remoteHello.nodeID,
            expectedSessionID: sessionID,
            publicKeyBase64: remoteHello.publicKeyBase64
        )
        authenticatedSessionState = .authenticated
        record(category: .authentication, state: "authenticated", peer: remoteHello.nodeID, detail: "Session is bound to paired keys and the fresh pairing transcript")
    }

    private func receiveReliableMessage(_ message: NearBridgeReliableMessage, peer: String?) throws {
        guard authenticatedSessionState == .authenticated, var validator = reliableValidator else {
            throw ReliableMessageError.unexpectedSender
        }
        let acceptance = try validator.validate(message)
        reliableValidator = validator
        switch acceptance {
        case .duplicateIgnored(let messageID):
            record(category: .messageReceive, state: "duplicateIgnored", peer: peer, message: messageID, detail: "Ignored duplicate message \(messageID.uuidString)")
            return
        case .accepted(let accepted):
            lastReceivedMessage = accepted
            record(category: .messageReceive, state: "accepted", peer: accepted.senderNodeID, message: accepted.messageID, detail: "Accepted signed \(accepted.displaySummary)")
            try respond(to: accepted)
        }
    }

    private func respond(to message: NearBridgeReliableMessage) throws {
        guard let identityManager, let sessionID = activeSessionID else {
            throw ReliableMessageError.wrongSession
        }
        switch message.messageType {
        case .ping:
            let pong = try ReliableMessageCodec.makePong(for: message, sessionID: sessionID, identityManager: identityManager)
            pendingAcknowledgements.insert(pong.messageID)
            send(pong, state: "responded")
            scheduleAcknowledgementTimeout(pong)
        case .pong:
            if let started = pendingPings.removeValue(forKey: message.correlationID) {
                roundTripMilliseconds = Date().timeIntervalSince(started) * 1_000
                pendingPingCount = pendingPings.count
            } else {
                record(category: .messageReceive, state: "uncorrelatedPong", peer: message.senderNodeID, message: message.messageID, detail: "Signed pong has no pending local ping")
            }
            send(
                try ReliableMessageCodec.makeAcknowledgement(for: message, sessionID: sessionID, identityManager: identityManager),
                state: "acknowledged"
            )
        case .acknowledgement:
            if pendingAcknowledgements.remove(message.correlationID) != nil {
                if lastExecutionReceipt?.resultMessageID == message.correlationID {
                    lastExecutionReceipt?.acknowledgement = .received
                }
                record(category: .messageReceive, state: "acknowledged", peer: message.senderNodeID, message: message.messageID, detail: "Peer acknowledged message \(message.correlationID.uuidString)")
            } else {
                record(category: .messageReceive, state: "unexpectedAcknowledgement", peer: message.senderNodeID, message: message.messageID, detail: "Acknowledgement has no pending local message")
            }
        case .contactRequest, .capabilityResponse, .contactAccepted, .contactCompleted:
            try receiveContactMessage(message)
            send(
                try ReliableMessageCodec.makeAcknowledgement(for: message, sessionID: sessionID, identityManager: identityManager),
                state: "acknowledged"
            )
        case .capabilityInvocation, .capabilityResult, .capabilityFailure:
            try receiveCapabilityMessage(message, identityManager: identityManager, sessionID: sessionID)
            let acknowledgement = try ReliableMessageCodec.makeAcknowledgement(
                for: message,
                sessionID: sessionID,
                identityManager: identityManager
            )
            send(acknowledgement, state: "acknowledged")
            if [.capabilityResult, .capabilityFailure].contains(message.messageType) {
                lastExecutionReceipt?.acknowledgement = .sent
            }
        }
    }

    private func send(_ message: NearBridgeReliableMessage, state: String) {
        do {
            lastSentMessage = message
            transport?.send(try ReliableMessageCodec.encode(message))
            record(category: .messageSend, state: state, peer: remoteHello?.nodeID, message: message.messageID, detail: "Sent signed \(message.displaySummary)")
        } catch {
            record(category: .messageSend, state: "encodingFailed", peer: remoteHello?.nodeID, error: error, detail: error.localizedDescription)
        }
    }

    private func schedulePingTimeout(_ ping: NearBridgeReliableMessage) {
        let messageID = ping.messageID
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, self.pendingPings.removeValue(forKey: messageID) != nil else { return }
            self.pendingPingCount = self.pendingPings.count
            self.record(category: .timeout, state: "timedOut", message: ping.messageID, detail: "No correlated signed pong within 3 seconds for sequence \(ping.payload.sequence ?? -1)")
        }
    }

    private func scheduleAcknowledgementTimeout(_ message: NearBridgeReliableMessage) {
        let messageID = message.messageID
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, self.pendingAcknowledgements.remove(messageID) != nil else { return }
            self.record(category: .timeout, state: "ackTimedOut", message: messageID, detail: "No signed acknowledgement within 3 seconds for message \(messageID.uuidString)")
        }
    }

    private func receiveContactMessage(_ message: NearBridgeReliableMessage) throws {
        try contactWorkflow.apply(message, direction: .received)
        switch message.messageType {
        case .contactRequest:
            contactRequestMessage = message
        case .capabilityResponse:
            capabilityResponseMessage = message
            remotePrimaryHolonDisclosure = message.payload.contact?.summary
        case .contactAccepted:
            contactAcceptanceMessage = message
        case .contactCompleted:
            break
        case .ping, .pong, .acknowledgement, .capabilityInvocation, .capabilityResult, .capabilityFailure:
            throw ContactWorkflowError.missingPayload
        }
        publishContactWorkflow()
        record(category: .workflow, state: contactWorkflow.state.rawValue, peer: message.senderNodeID, message: message.messageID, detail: message.payload.contact?.summary ?? message.messageType.rawValue)
    }

    private func sendContactMessage(_ message: NearBridgeReliableMessage, state: String) {
        pendingAcknowledgements.insert(message.messageID)
        send(message, state: state)
        scheduleAcknowledgementTimeout(message)
        record(category: .workflow, state: contactWorkflow.state.rawValue, peer: remoteHello?.nodeID, message: message.messageID, detail: message.payload.contact?.summary ?? message.messageType.rawValue)
    }

    private func receiveCapabilityMessage(
        _ message: NearBridgeReliableMessage,
        identityManager: HostIdentityManager,
        sessionID: String
    ) throws {
        guard let payload = message.payload.capability else { throw CapabilityError.invalidMessage }
        switch message.messageType {
        case .capabilityInvocation:
            guard role == .mac else { throw CapabilityError.wrongRole }
            guard contactWorkflowState == .completed else {
                sendCapabilityFailure(for: message, reason: "Contact workflow is not completed", identityManager: identityManager, sessionID: sessionID)
                return
            }
            guard activeHostCapabilityInvocationID == nil else {
                sendCapabilityFailure(for: message, reason: "The Host is already executing one capability request", identityManager: identityManager, sessionID: sessionID)
                return
            }
            activeHostCapabilityInvocationID = payload.invocationID
            capabilityExecutionState = .executing
            lastExecutionReceipt = NearBridgeExecutionReceipt(
                invocationID: payload.invocationID,
                capabilityID: payload.capabilityID,
                providerLabel: selectedPrimaryHolon?.displayName ?? "Selected Mac Primary Holon",
                peerFingerprint: remoteFingerprint,
                outcome: .executing,
                integrity: "Accepted signed invocation after Host policy checks"
            )
            record(category: .capability, state: "executing", peer: message.senderNodeID, message: message.messageID, detail: "Host authorized registered capability \(payload.capabilityID)")
            Task { [weak self] in
                await self?.executeHostCapabilityInvocation(
                    message,
                    payload: payload,
                    identityManager: identityManager,
                    sessionID: sessionID
                )
            }

        case .capabilityResult, .capabilityFailure:
            guard role == .iPhone, let pending = pendingCapabilityInvocation,
                  let pendingPayload = pending.payload.capability else { throw CapabilityError.correlationMismatch }
            guard message.correlationID == pending.messageID,
                  payload.invocationID == pendingPayload.invocationID,
                  payload.capabilityID == pendingPayload.capabilityID else {
                throw CapabilityError.correlationMismatch
            }
            pendingCapabilityInvocation = nil
            lastCapabilityOutput = payload.outputText
            capabilityExecutionState = message.messageType == .capabilityResult ? .succeeded : .failed
            lastExecutionReceipt?.completedAt = Date()
            lastExecutionReceipt?.outcome = message.messageType == .capabilityResult ? .succeeded : .failed
            lastExecutionReceipt?.integrity = "Host signature, session, expiry, and correlation validated"
            lastExecutionReceipt?.resultMessageID = message.messageID
            record(
                category: .capability,
                state: capabilityExecutionState.rawValue,
                peer: message.senderNodeID,
                message: message.messageID,
                detail: message.messageType == .capabilityResult ? "Received result from the registered Mac Host capability" : "Mac Host rejected the capability invocation"
            )

        case .ping, .pong, .acknowledgement, .contactRequest, .capabilityResponse, .contactAccepted, .contactCompleted:
            throw CapabilityError.invalidMessage
        }
    }

    private func executeHostCapabilityInvocation(
        _ message: NearBridgeReliableMessage,
        payload: CapabilityMessagePayload,
        identityManager: HostIdentityManager,
        sessionID: String
    ) async {
        defer {
            if activeHostCapabilityInvocationID == payload.invocationID {
                activeHostCapabilityInvocationID = nil
            }
        }
        do {
            let output = try await capabilityRegistry.execute(
                payload,
                safetyIdentifier: NearBridgeSafetyIdentifier.forSession(sessionID)
            )
            guard activeSessionID == sessionID,
                  authenticatedSessionState == .authenticated else {
                capabilityExecutionState = .failed
                lastCapabilityOutput = "The authenticated session ended before the result was returned"
                record(category: .capability, state: "resultDiscarded", peer: message.senderNodeID, message: message.messageID, detail: "Discarded model output after the authenticated session ended")
                return
            }
            let result = try ReliableMessageCodec.makeCapabilityResult(
                for: message,
                output: output,
                sessionID: sessionID,
                identityManager: identityManager
            )
            capabilityExecutionState = .succeeded
            lastCapabilityOutput = output
            lastExecutionReceipt?.completedAt = Date()
            lastExecutionReceipt?.outcome = .succeeded
            lastExecutionReceipt?.integrity = "Host signed a typed result bound to the fresh session"
            lastExecutionReceipt?.resultMessageID = result.messageID
            sendCapabilityMessage(result, state: "resultSent")
        } catch {
            guard activeSessionID == sessionID,
                  authenticatedSessionState == .authenticated else { return }
            sendCapabilityFailure(
                for: message,
                reason: error.localizedDescription,
                identityManager: identityManager,
                sessionID: sessionID
            )
        }
    }

    private func sendCapabilityFailure(
        for invocation: NearBridgeReliableMessage,
        reason: String,
        identityManager: HostIdentityManager,
        sessionID: String
    ) {
        do {
            let failure = try ReliableMessageCodec.makeCapabilityFailure(
                for: invocation,
                reason: reason,
                sessionID: sessionID,
                identityManager: identityManager
            )
            capabilityExecutionState = .failed
            lastCapabilityOutput = reason
            lastExecutionReceipt?.completedAt = Date()
            lastExecutionReceipt?.outcome = .failed
            lastExecutionReceipt?.integrity = "Host signed a bounded failure bound to the fresh session"
            lastExecutionReceipt?.resultMessageID = failure.messageID
            sendCapabilityMessage(failure, state: "failureSent")
        } catch {
            record(category: .capability, state: "failureEncodingFailed", error: error, detail: error.localizedDescription)
        }
    }

    private func sendCapabilityMessage(_ message: NearBridgeReliableMessage, state: String) {
        pendingAcknowledgements.insert(message.messageID)
        send(message, state: state)
        scheduleAcknowledgementTimeout(message)
        record(category: .capability, state: state, peer: remoteHello?.nodeID, message: message.messageID, detail: message.displaySummary)
    }

    private func authenticatedContext() throws -> (identity: HostIdentityManager, sessionID: String) {
        guard authenticatedSessionState == .authenticated, let identityManager, let activeSessionID else {
            throw ReliableMessageError.wrongSession
        }
        return (identityManager, activeSessionID)
    }

    private func publishContactWorkflow() {
        contactWorkflowState = contactWorkflow.state
        contactWorkflowSummary = contactWorkflow.summary
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

    private func resetHandshake() {
        pairingMachine = NearBridgePairingStateMachine()
        localHello = nil
        remoteHello = nil
        transcriptHash = nil
        activePeerReference = nil
        pendingPairing = nil
        reliableValidator = nil
        activeSessionID = nil
        authenticatedSessionState = .idle
        pendingPings.removeAll()
        pendingPingCount = 0
        pendingAcknowledgements.removeAll()
        contactWorkflow.reset()
        contactWorkflowState = .idle
        contactWorkflowSummary = nil
        contactRequestMessage = nil
        capabilityResponseMessage = nil
        contactAcceptanceMessage = nil
        pendingCapabilityInvocation = nil
        activeHostCapabilityInvocationID = nil
        capabilityExecutionState = .idle
        lastCapabilityOutput = nil
        remotePrimaryHolonDisclosure = nil
        lastExecutionReceipt = nil
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
        message: UUID? = nil,
        error: Error? = nil,
        detail: String
    ) {
        let event = NearBridgeEvent(
            phase: phase,
            deviceRole: role,
            category: category,
            state: state,
            peerReference: peer,
            messageReference: message,
            error: error,
            humanReadableDetail: detail
        )
        events.insert(event, at: 0)
        if events.count > 300 { events.removeLast(events.count - 300) }
        logger.info("\(event.compactDescription, privacy: .public)")
    }
}
