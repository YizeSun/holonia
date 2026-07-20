import Foundation
import Network

final class BonjourNetworkTransport: ExperimentTransport {
    var onEvent: ((TransportEvent) -> Void)?
    var onPeersChanged: (([ExperimentPeer]) -> Void)?
    var onData: ((Data, String?) -> Void)?

    private static let serviceType = "_nearbridge-v0._tcp"
    private let queue = DispatchQueue(label: "org.holonia.nearbridge.v0.bonjour")
    private let serviceName: String
    private let allowsSessions: Bool
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var endpoints: [String: NWEndpoint] = [:]
    private var receiveBuffer = Data()
    private var reconnectEndpoint: NWEndpoint?
    private var reconnectWorkItem: DispatchWorkItem?
    private var isRunning = false
    private var intentionalDisconnect = false
    private var connectionIsReady = false

    init(role: DeviceRole, allowsSessions: Bool = true) {
        serviceName = "NearBridge-\(role.rawValue)-\(UUID().uuidString.prefix(4))"
        self.allowsSessions = allowsSessions
    }

    func start() {
        queue.async { self.startOnQueue() }
    }

    func stop() {
        queue.async { self.stopOnQueue() }
    }

    func connect(to peerID: String) {
        queue.async { self.connectOnQueue(to: peerID) }
    }

    func disconnect() {
        queue.async { self.disconnectOnQueue() }
    }

    func send(_ data: Data) {
        queue.async { self.sendOnQueue(data) }
    }

    private func startOnQueue() {
        guard !isRunning else { return }
        isRunning = true
        intentionalDisconnect = false
        do {
            let listener = try NWListener(using: .tcp)
            listener.service = .init(name: serviceName, type: Self.serviceType)
            listener.stateUpdateHandler = { [weak self] state in self?.handleListener(state) }
            listener.newConnectionHandler = { [weak self] connection in
                guard let self else { return }
                guard self.allowsSessions else {
                    self.emit(.invitation, "rejectedByPhase", peer: String(describing: connection.endpoint), detail: "NB-1 discovery rejects all inbound sessions")
                    connection.cancel()
                    return
                }
                if self.connectionIsReady {
                    self.emit(.connection, "duplicateRejected", peer: String(describing: connection.endpoint), detail: "Rejected an additional inbound TCP connection while one session is active")
                    connection.cancel()
                    return
                }
                self.emit(.invitation, "received", peer: String(describing: connection.endpoint), detail: "Accepted inbound untrusted TCP session")
                self.install(connection, reconnectEndpoint: nil)
            }
            self.listener = listener
            listener.start(queue: queue)
        } catch {
            emit(.frameworkError, "failed", detail: "Could not create Bonjour listener", error: error)
        }

        let browser = NWBrowser(for: .bonjour(type: Self.serviceType, domain: nil), using: .tcp)
        browser.stateUpdateHandler = { [weak self] state in self?.handleBrowser(state) }
        browser.browseResultsChangedHandler = { [weak self] results, changes in
            self?.update(results: results, changes: changes)
        }
        self.browser = browser
        browser.start(queue: queue)
    }

    private func stopOnQueue() {
        isRunning = false
        intentionalDisconnect = true
        reconnectWorkItem?.cancel()
        browser?.cancel()
        listener?.cancel()
        connection?.cancel()
        browser = nil
        listener = nil
        connection = nil
        connectionIsReady = false
        reconnectEndpoint = nil
        endpoints = [:]
        onPeersChanged?([])
    }

    private func connectOnQueue(to peerID: String) {
        guard allowsSessions else {
            emit(.connection, "rejectedByPhase", peer: peerID, detail: "NB-1 discovery cannot create sessions")
            return
        }
        guard !connectionIsReady else {
            emit(.connection, "alreadyConnected", peer: peerID, detail: "Ignored Connect because an active TCP session already exists")
            return
        }
        guard let endpoint = endpoints[peerID] else {
            emit(.frameworkError, "peerUnavailable", peer: peerID, detail: "Selected Bonjour endpoint is no longer available")
            return
        }
        intentionalDisconnect = false
        onEvent?(.session(.connecting, peer: peerID))
        install(NWConnection(to: endpoint, using: .tcp), reconnectEndpoint: endpoint)
    }

    private func disconnectOnQueue() {
        intentionalDisconnect = true
        reconnectWorkItem?.cancel()
        reconnectEndpoint = nil
        connection?.cancel()
        connection = nil
        connectionIsReady = false
        onEvent?(.session(.disconnected, peer: nil))
    }

    private func sendOnQueue(_ data: Data) {
        guard allowsSessions else {
            emit(.messageSend, "rejectedByPhase", detail: "NB-1 discovery cannot send session messages")
            return
        }
        guard let connection, connectionIsReady else {
            emit(.frameworkError, "sessionNotReady", detail: "No ready TCP session is available for sending")
            return
        }
        var framed = data
        framed.append(0x0A)
        connection.send(content: framed, completion: .contentProcessed { [weak self] error in
            if let error {
                self?.emit(.frameworkError, "sendFailed", detail: "TCP send failed", error: error)
            } else {
                self?.emit(.messageSend, MessageState.sent.rawValue, detail: "TCP message sent")
            }
        })
    }

    private func install(_ newConnection: NWConnection, reconnectEndpoint: NWEndpoint?) {
        connection?.cancel()
        connection = newConnection
        connectionIsReady = false
        self.reconnectEndpoint = reconnectEndpoint
        receiveBuffer = Data()
        newConnection.stateUpdateHandler = { [weak self, weak newConnection] state in
            guard let self, let newConnection, self.connection === newConnection else { return }
            self.handleConnection(state, connection: newConnection)
        }
        newConnection.start(queue: queue)
    }

    private func receive(on activeConnection: NWConnection) {
        activeConnection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self, weak activeConnection] data, _, isComplete, error in
            guard let self, let activeConnection, self.connection === activeConnection else { return }
            if let data { self.consume(data, peer: String(describing: activeConnection.endpoint)) }
            if let error {
                self.emit(.frameworkError, "receiveFailed", detail: "TCP receive failed", error: error)
                return
            }
            if isComplete {
                self.connectionEnded(peer: String(describing: activeConnection.endpoint))
            } else {
                self.receive(on: activeConnection)
            }
        }
    }

    private func consume(_ data: Data, peer: String) {
        receiveBuffer.append(data)
        while let newline = receiveBuffer.firstIndex(of: 0x0A) {
            let frame = Data(receiveBuffer[..<newline])
            receiveBuffer.removeSubrange(...newline)
            guard !frame.isEmpty else { continue }
            onData?(frame, peer)
        }
    }

    private func handleListener(_ state: NWListener.State) {
        switch state {
        case .ready:
            emit(.advertisement, DiscoveryState.advertising.rawValue, detail: "Advertising \(serviceName) with minimal discovery metadata")
        case .waiting(let error):
            emit(.localNetworkPermission, "waiting", detail: "Listener is waiting; Local Network permission or network availability may be involved", error: error)
        case .failed(let error):
            emit(.frameworkError, "listenerFailed", detail: "Bonjour listener failed", error: error)
        default:
            break
        }
    }

    private func handleBrowser(_ state: NWBrowser.State) {
        switch state {
        case .ready:
            emit(.browsing, DiscoveryState.browsing.rawValue, detail: "Browsing for \(Self.serviceType)")
        case .waiting(let error):
            emit(.localNetworkPermission, "waiting", detail: "Browser is waiting; check Local Network permission and Wi-Fi", error: error)
        case .failed(let error):
            emit(.frameworkError, "browserFailed", detail: "Bonjour browser failed", error: error)
        default:
            break
        }
    }

    private func update(results: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>) {
        var updated: [String: NWEndpoint] = [:]
        var peers: [ExperimentPeer] = []
        for result in results {
            if case .service(let name, _, _, _) = result.endpoint, name == serviceName {
                continue
            }
            let identifier = String(describing: result.endpoint)
            updated[identifier] = result.endpoint
            peers.append(.init(id: identifier, displayName: displayName(for: result.endpoint), endpointDescription: identifier))
        }
        endpoints = updated
        onPeersChanged?(peers.sorted { $0.displayName < $1.displayName })
        for change in changes {
            switch change {
            case .added(let result):
                if isOwnService(result.endpoint) { continue }
                emit(.peerDiscovered, DiscoveryState.peerDiscovered.rawValue, peer: String(describing: result.endpoint), detail: "Bonjour service discovered; this is not authentication")
            case .removed(let result):
                if isOwnService(result.endpoint) { continue }
                emit(.peerLost, DiscoveryState.peerLost.rawValue, peer: String(describing: result.endpoint), detail: "Bonjour service disappeared")
            default:
                break
            }
        }
    }

    private func displayName(for endpoint: NWEndpoint) -> String {
        if case .service(let name, _, _, _) = endpoint { return name }
        return String(describing: endpoint)
    }

    private func isOwnService(_ endpoint: NWEndpoint) -> Bool {
        if case .service(let name, _, _, _) = endpoint { return name == serviceName }
        return false
    }

    private func handleConnection(_ state: NWConnection.State, connection activeConnection: NWConnection) {
        let peer = String(describing: activeConnection.endpoint)
        switch state {
        case .ready:
            connectionIsReady = true
            onEvent?(.session(.connected, peer: peer))
            receive(on: activeConnection)
        case .waiting(let error):
            emit(.frameworkError, "connectionWaiting", peer: peer, detail: "TCP connection is waiting", error: error)
        case .failed(let error):
            emit(.frameworkError, "connectionFailed", peer: peer, detail: "TCP connection failed", error: error)
            connectionEnded(peer: peer)
        case .cancelled:
            connectionEnded(peer: peer)
        default:
            break
        }
    }

    private func connectionEnded(peer: String) {
        connectionIsReady = false
        connection = nil
        onEvent?(.session(.disconnected, peer: peer))
        guard isRunning, !intentionalDisconnect, reconnectEndpoint != nil else { return }
        scheduleReconnect(peer: peer)
    }

    private func scheduleReconnect(peer: String) {
        reconnectWorkItem?.cancel()
        onEvent?(.session(.reconnecting, peer: peer))
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isRunning, let endpoint = self.reconnectEndpoint else { return }
            self.install(NWConnection(to: endpoint, using: .tcp), reconnectEndpoint: endpoint)
        }
        reconnectWorkItem = work
        queue.asyncAfter(deadline: .now() + 2, execute: work)
    }

    private func emit(_ category: ExperimentEventCategory, _ state: String, peer: String? = nil, detail: String, error: Error? = nil) {
        let diagnosticDetail: String
        if let error {
            diagnosticDetail = "\(detail): \(String(reflecting: error))"
        } else {
            diagnosticDetail = detail
        }
        onEvent?(.diagnostic(category: category, state: state, peer: peer, detail: diagnosticDetail, error: error))
    }
}
