import Combine
import Foundation
import os

@MainActor
public final class ExperimentController: ObservableObject {
    @Published public var selectedExperiment: ExperimentKind = .bonjourNetwork
    @Published public private(set) var peers: [ExperimentPeer] = []
    @Published public private(set) var discoveryState: DiscoveryState = .stopped
    @Published public private(set) var sessionState: SessionState = .idle
    @Published public private(set) var lastReceivedMessage: ExperimentMessage?
    @Published public private(set) var lastSentMessage: ExperimentMessage?
    @Published public private(set) var roundTripMilliseconds: Double?
    @Published public private(set) var pendingPingCount = 0
    @Published public private(set) var events: [ExperimentEvent] = []
    @Published public private(set) var isRunning = false

    public let role: DeviceRole
    private var transport: ExperimentTransport?
    private var sequence = 0
    private var pendingPings: [UUID: Date] = [:]
    private var receivedIdentifiers = MessageIdentifierTracker()
    private let logger = Logger(subsystem: "org.holonia.nearbridge.nb0", category: "experiment")

    public init(role: DeviceRole) {
        self.role = role
    }

    public func select(_ experiment: ExperimentKind) {
        guard experiment != selectedExperiment else { return }
        stop()
        selectedExperiment = experiment
        record(category: .applicationLifecycle, state: "experimentSelected", detail: experiment.rawValue)
    }

    public func start() {
        guard !isRunning else { return }
        let candidate: ExperimentTransport
        switch selectedExperiment {
        case .bonjourNetwork:
            candidate = BonjourNetworkTransport(role: role)
        case .multipeerConnectivity:
            candidate = MultipeerTransport(role: role)
        case .udpMulticastProbe:
            candidate = UDPMulticastProbeTransport(role: role)
        }
        bind(candidate)
        transport = candidate
        isRunning = true
        discoveryState = .starting
        record(category: .applicationLifecycle, state: "started", detail: "User started the experiment")
        candidate.start()
    }

    public func stop() {
        transport?.stop()
        transport = nil
        isRunning = false
        peers = []
        discoveryState = .stopped
        sessionState = .idle
        pendingPings = [:]
        pendingPingCount = 0
        record(category: .applicationLifecycle, state: "stopped", detail: "User stopped the experiment")
    }

    public func connect(to peer: ExperimentPeer) {
        guard selectedExperiment.supportsSessions else {
            record(category: .connection, state: "notSupported", peer: peer.id, detail: "UDP is a discovery probe only")
            return
        }
        guard ![.connecting, .connected, .disconnecting, .reconnecting].contains(sessionState) else {
            record(category: .connection, state: "alreadyActive", peer: peer.id, detail: "Ignored Connect because a session is already active or changing state")
            return
        }
        sessionState = .connecting
        transport?.connect(to: peer.id)
    }

    public func disconnect() {
        sessionState = .disconnecting
        transport?.disconnect()
    }

    public func sendPing() {
        guard isRunning else { return }
        if selectedExperiment.supportsSessions && sessionState != .connected {
            record(category: .messageSend, state: MessageState.failed.rawValue, detail: "Connect a session before sending ping")
            return
        }
        sequence += 1
        let ping = ExperimentMessage.ping(sequence: sequence)
        do {
            let data = try ExperimentMessageCodec.encode(ping)
            pendingPings[ping.correlationID] = Date()
            pendingPingCount = pendingPings.count
            lastSentMessage = ping
            record(category: .messageSend, state: MessageState.sending.rawValue, message: ping.messageID, detail: "Ping sequence \(sequence)")
            transport?.send(data)
            scheduleTimeout(for: ping)
        } catch {
            record(category: .messageSend, state: MessageState.failed.rawValue, message: ping.messageID, error: error, detail: error.localizedDescription)
        }
    }

    public func recordLifecycle(_ state: String) {
        record(category: .applicationLifecycle, state: state, detail: "Application scene is \(state)")
    }

    private func bind(_ candidate: ExperimentTransport) {
        candidate.onPeersChanged = { [weak self] peers in
            DispatchQueue.main.async {
                guard let self else { return }
                self.peers = peers
                self.discoveryState = peers.isEmpty ? .browsing : .peerDiscovered
            }
        }
        candidate.onMessage = { [weak self] message, peer in
            DispatchQueue.main.async { self?.receive(message, peer: peer) }
        }
        candidate.onEvent = { [weak self] event in
            DispatchQueue.main.async { self?.handle(event) }
        }
    }

    private func handle(_ transportEvent: TransportEvent) {
        switch transportEvent {
        case .session(let state, let peer):
            sessionState = state
            let category: ExperimentEventCategory = state == .reconnecting ? .reconnection : (state == .disconnected ? .disconnection : .connection)
            record(category: category, state: state.rawValue, peer: peer, detail: "Session state changed to \(state.rawValue)")
        case .diagnostic(let category, let state, let peer, let detail, let error):
            if category == .advertisement { discoveryState = .advertising }
            if category == .browsing { discoveryState = .browsing }
            if category == .frameworkError && ["failed", "listenerFailed", "browserFailed", "advertiseFailed", "browseFailed"].contains(state) {
                discoveryState = .failed
            }
            if category == .frameworkError && ["sendFailed", "sessionNotReady"].contains(state) {
                pendingPings.removeAll()
                pendingPingCount = 0
            }
            record(category: category, state: state, peer: peer, error: error, detail: detail)
        }
    }

    private func receive(_ message: ExperimentMessage, peer: String?) {
        guard receivedIdentifiers.insert(message.messageID) else {
            record(category: .messageReceive, state: "duplicateIgnored", peer: peer, message: message.messageID, detail: "Duplicate message identifier")
            return
        }
        lastReceivedMessage = message
        record(category: .messageReceive, state: MessageState.received.rawValue, peer: peer, message: message.messageID, detail: "Received \(message.messageType.rawValue) sequence \(message.payload.sequence)")

        switch message.messageType {
        case .ping:
            guard selectedExperiment.supportsSessions else { return }
            do {
                let pong = ExperimentMessage.pong(for: message)
                transport?.send(try ExperimentMessageCodec.encode(pong))
                record(category: .messageSend, state: MessageState.responded.rawValue, peer: peer, message: pong.messageID, detail: "Pong for sequence \(pong.payload.sequence)")
            } catch {
                record(category: .messageSend, state: MessageState.failed.rawValue, peer: peer, error: error, detail: error.localizedDescription)
            }
        case .pong:
            if let started = pendingPings.removeValue(forKey: message.correlationID) {
                roundTripMilliseconds = Date().timeIntervalSince(started) * 1_000
                pendingPingCount = pendingPings.count
            }
        }
    }

    private func scheduleTimeout(for ping: ExperimentMessage) {
        let correlationID = ping.correlationID
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, self.pendingPings.removeValue(forKey: correlationID) != nil else { return }
            self.pendingPingCount = self.pendingPings.count
            self.record(
                category: .timeout,
                state: MessageState.timedOut.rawValue,
                message: ping.messageID,
                detail: "No correlated pong received within 3 seconds for ping sequence \(ping.payload.sequence)"
            )
        }
    }

    private func record(
        category: ExperimentEventCategory,
        state: String,
        peer: String? = nil,
        message: UUID? = nil,
        error: Error? = nil,
        detail: String
    ) {
        let event = ExperimentEvent(
            deviceRole: role,
            experiment: selectedExperiment,
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
