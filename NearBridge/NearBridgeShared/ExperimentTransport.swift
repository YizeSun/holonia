import Foundation

protocol ExperimentTransport: AnyObject {
    var onEvent: ((TransportEvent) -> Void)? { get set }
    var onPeersChanged: (([ExperimentPeer]) -> Void)? { get set }
    var onMessage: ((ExperimentMessage, String?) -> Void)? { get set }

    func start()
    func stop()
    func connect(to peerID: String)
    func disconnect()
    func send(_ data: Data)
}

enum TransportEvent {
    case diagnostic(category: ExperimentEventCategory, state: String, peer: String?, detail: String, error: Error?)
    case session(SessionState, peer: String?)
}
