import Foundation
import MultipeerConnectivity

final class MultipeerTransport: NSObject, ExperimentTransport {
    var onEvent: ((TransportEvent) -> Void)?
    var onPeersChanged: (([ExperimentPeer]) -> Void)?
    var onMessage: ((ExperimentMessage, String?) -> Void)?

    private static let serviceType = "nb0-bridge"
    private let localPeer: MCPeerID
    private let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser
    private var discovered: [String: MCPeerID] = [:]

    init(role: DeviceRole) {
        localPeer = MCPeerID(displayName: "NB0-\(role.rawValue)-\(UUID().uuidString.prefix(4))")
        session = MCSession(peer: localPeer, securityIdentity: nil, encryptionPreference: .required)
        advertiser = MCNearbyServiceAdvertiser(peer: localPeer, discoveryInfo: ["v": "1"], serviceType: Self.serviceType)
        browser = MCNearbyServiceBrowser(peer: localPeer, serviceType: Self.serviceType)
        super.init()
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
    }

    func start() {
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        emit(.advertisement, DiscoveryState.advertising.rawValue, detail: "Advertising ephemeral MPC peer with schema version only")
        emit(.browsing, DiscoveryState.browsing.rawValue, detail: "Browsing for MPC peers")
    }

    func stop() {
        browser.stopBrowsingForPeers()
        advertiser.stopAdvertisingPeer()
        session.disconnect()
        discovered = [:]
        onPeersChanged?([])
    }

    func connect(to peerID: String) {
        guard let peer = discovered[peerID] else {
            emit(.frameworkError, "peerUnavailable", peer: peerID, detail: "Selected MPC peer is no longer visible")
            return
        }
        onEvent?(.session(.connecting, peer: peerID))
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 20)
        emit(.invitation, "sent", peer: peerID, detail: "Sent untrusted NB-0 invitation")
    }

    func disconnect() {
        session.disconnect()
        onEvent?(.session(.disconnected, peer: nil))
    }

    func send(_ data: Data) {
        guard !session.connectedPeers.isEmpty else {
            emit(.frameworkError, "notConnected", detail: "No MPC session is available")
            return
        }
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            emit(.messageSend, MessageState.sent.rawValue, detail: "Reliable MPC message sent")
        } catch {
            emit(.frameworkError, "sendFailed", detail: "MPC send failed", error: error)
        }
    }

    private func publishPeers() {
        onPeersChanged?(discovered.values.map {
            .init(id: $0.displayName, displayName: $0.displayName, endpointDescription: "MCPeerID (ephemeral)")
        }.sorted { $0.displayName < $1.displayName })
    }

    private func emit(_ category: ExperimentEventCategory, _ state: String, peer: String? = nil, detail: String, error: Error? = nil) {
        let diagnosticDetail = error.map { "\(detail): \(String(reflecting: $0))" } ?? detail
        onEvent?(.diagnostic(category: category, state: state, peer: peer, detail: diagnosticDetail, error: error))
    }
}

extension MultipeerTransport: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        discovered[peerID.displayName] = peerID
        publishPeers()
        emit(.peerDiscovered, DiscoveryState.peerDiscovered.rawValue, peer: peerID.displayName, detail: "MPC peer discovered; this identifier is not authentication")
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        discovered.removeValue(forKey: peerID.displayName)
        publishPeers()
        emit(.peerLost, DiscoveryState.peerLost.rawValue, peer: peerID.displayName, detail: "MPC peer lost")
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        emit(.frameworkError, "browseFailed", detail: "MPC browsing failed", error: error)
    }
}

extension MultipeerTransport: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        emit(.invitation, "received", peer: peerID.displayName, detail: "Accepted an NB-0 invitation automatically; this is not pairing or authorization")
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        emit(.frameworkError, "advertiseFailed", detail: "MPC advertising failed", error: error)
    }
}

extension MultipeerTransport: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .notConnected:
            onEvent?(.session(.disconnected, peer: peerID.displayName))
        case .connecting:
            onEvent?(.session(.connecting, peer: peerID.displayName))
        case .connected:
            onEvent?(.session(.connected, peer: peerID.displayName))
        @unknown default:
            emit(.frameworkError, "unknownSessionState", peer: peerID.displayName, detail: "MPC returned an unknown session state")
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            onMessage?(try ExperimentMessageCodec.decode(data), peerID.displayName)
        } catch {
            emit(.decodingError, "rejected", peer: peerID.displayName, detail: "Rejected malformed or unsupported MPC message", error: error)
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        emit(.frameworkError, "streamRejected", peer: peerID.displayName, detail: "NB-0 does not accept streams or file transfer")
        stream.close()
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        progress.cancel()
        emit(.frameworkError, "resourceRejected", peer: peerID.displayName, detail: "NB-0 rejects resource transfer")
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        emit(.frameworkError, "resourceRejected", peer: peerID.displayName, detail: "NB-0 does not accept resources", error: error)
    }
}
