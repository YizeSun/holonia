import Foundation
import Network

final class UDPMulticastProbeTransport: ExperimentTransport {
    var onEvent: ((TransportEvent) -> Void)?
    var onPeersChanged: (([ExperimentPeer]) -> Void)?
    var onData: ((Data, String?) -> Void)?

    private let queue = DispatchQueue(label: "org.holonia.nearbridge.nb0.udp")
    private var group: NWConnectionGroup?

    init(role: DeviceRole) {}

    func start() {
        do {
            let endpoint = NWEndpoint.hostPort(host: "239.255.42.99", port: 42_424)
            let descriptor = try NWMulticastGroup(for: [endpoint])
            let parameters = NWParameters.udp
            parameters.allowLocalEndpointReuse = true
            let group = NWConnectionGroup(with: descriptor, using: parameters)
            group.stateUpdateHandler = { [weak self] state in self?.handle(state) }
            group.setReceiveHandler(maximumMessageSize: 4_096, rejectOversizedMessages: true) { [weak self] message, data, _ in
                guard let self, let data else { return }
                let peer = String(describing: message.remoteEndpoint)
                self.onData?(data, peer)
                self.emit(.peerDiscovered, "datagramReceived", peer: peer, detail: "Received non-sensitive multicast probe; source is not identity")
            }
            self.group = group
            group.start(queue: queue)
        } catch {
            emit(.frameworkError, "groupCreationFailed", detail: "Could not create UDP multicast group", error: error)
        }
    }

    func stop() {
        group?.cancel()
        group = nil
        onPeersChanged?([])
    }

    func connect(to peerID: String) {
        emit(.connection, "notSupported", detail: "UDP remains a discovery probe and does not create a session")
    }

    func disconnect() {}

    func send(_ data: Data) {
        guard let group else {
            emit(.frameworkError, "notRunning", detail: "UDP multicast group is not running")
            return
        }
        group.send(content: data) { [weak self] error in
            if let error {
                self?.emit(.frameworkError, "sendFailed", detail: "UDP multicast send failed", error: error)
            } else {
                self?.emit(.messageSend, MessageState.sent.rawValue, detail: "Sent one non-sensitive multicast probe")
            }
        }
    }

    private func handle(_ state: NWConnectionGroup.State) {
        switch state {
        case .ready:
            emit(.advertisement, "probeReady", detail: "UDP multicast probe is ready; no reliable session exists")
            emit(.browsing, DiscoveryState.browsing.rawValue, detail: "Listening on 239.255.42.99:42424")
        case .waiting(let error):
            emit(.localNetworkPermission, "waiting", detail: "Multicast group is waiting; permission, entitlement, or network support may be involved", error: error)
        case .failed(let error):
            emit(.frameworkError, "groupFailed", detail: "UDP multicast group failed", error: error)
        default:
            break
        }
    }

    private func emit(_ category: ExperimentEventCategory, _ state: String, peer: String? = nil, detail: String, error: Error? = nil) {
        let diagnosticDetail = error.map { "\(detail): \(String(reflecting: $0))" } ?? detail
        onEvent?(.diagnostic(category: category, state: state, peer: peer, detail: diagnosticDetail, error: error))
    }
}
