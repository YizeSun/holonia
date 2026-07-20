import Combine
import Foundation
import os

@MainActor
public final class NearBridgeController: ObservableObject {
    @Published public private(set) var peers: [NearBridgePeer] = []
    @Published public private(set) var discoveryState: DiscoveryState = .stopped
    @Published public private(set) var localNetworkAccess: LocalNetworkAccessState = .unknown
    @Published public private(set) var events: [NearBridgeEvent] = []
    @Published public private(set) var isRunning = false

    public let role: DeviceRole
    public let phase = NearBridgeBuild.phase

    private var transport: BonjourNetworkTransport?
    private var registry = NearBridgeDiscoveryRegistry()
    private let logger = Logger(subsystem: "org.holonia.nearbridge.v0", category: "discovery")

    public init(role: DeviceRole) {
        self.role = role
    }

    public func start() {
        guard !isRunning else { return }
        let transport = BonjourNetworkTransport(role: role, allowsSessions: phase.allowsTransportSessions)
        bind(transport)
        self.transport = transport
        isRunning = true
        discoveryState = .starting
        record(category: .applicationLifecycle, state: "started", detail: "User launched NearBridge discovery")
        transport.start()
    }

    public func stop() {
        transport?.stop()
        transport = nil
        isRunning = false
        for change in registry.removeAll() { record(change) }
        peers = []
        discoveryState = .stopped
        record(category: .applicationLifecycle, state: "stopped", detail: "NearBridge discovery stopped")
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
        transport.onMessage = { _, _ in }
        transport.onEvent = { [weak self] event in
            DispatchQueue.main.async { self?.handle(event) }
        }
    }

    private func handle(_ transportEvent: TransportEvent) {
        guard case .diagnostic(let category, let state, let peer, let detail, let error) = transportEvent else {
            return
        }
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
        case .frameworkError:
            if ["listenerFailed", "browserFailed", "failed"].contains(state) {
                discoveryState = .failed
            }
            record(category: .frameworkError, state: state, peer: peer, error: error, detail: detail)
        case .peerDiscovered, .peerLost:
            break
        default:
            record(category: .discovery, state: state, peer: peer, error: error, detail: detail)
        }
    }

    private func record(_ change: NearBridgeDiscoveryChange) {
        switch change {
        case .found(let peer):
            record(
                category: .peerFound,
                state: "untrusted",
                peer: peer.id,
                detail: "Discovered \(peer.displayName); discovery is not authentication"
            )
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
