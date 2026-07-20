import XCTest
@testable import NearBridgeShared

final class NearBridgeDiscoveryTests: XCTestCase {
    func testNB1PolicyDisablesTransportSessions() {
        XCTAssertFalse(NearBridgePhase.nb1.allowsTransportSessions)
        XCTAssertTrue(NearBridgePhase.nb2.allowsTransportSessions)
    }

    func testRegistryDeduplicatesAndPreservesFirstSeen() {
        var registry = NearBridgeDiscoveryRegistry()
        let first = Date(timeIntervalSince1970: 100)
        let second = Date(timeIntervalSince1970: 200)
        let observation = ExperimentPeer(id: "service-a", displayName: "NearBridge-mac-1234", endpointDescription: "service-a.local")

        XCTAssertEqual(registry.reconcile([observation, observation], at: first).count, 1)
        XCTAssertEqual(registry.reconcile([observation], at: second), [])
        XCTAssertEqual(registry.peers.count, 1)
        XCTAssertEqual(registry.peers[0].firstSeenAt, first)
        XCTAssertEqual(registry.peers[0].lastSeenAt, second)
        XCTAssertEqual(registry.peers[0].roleHint, .mac)
        XCTAssertEqual(registry.peers[0].trustState, .untrusted)
    }

    func testRegistryEmitsLostAndNeverPromotesTrust() {
        var registry = NearBridgeDiscoveryRegistry()
        let observation = ExperimentPeer(id: "service-b", displayName: "NearBridge-iPhone-5678", endpointDescription: "service-b.local")
        _ = registry.reconcile([observation])

        let changes = registry.reconcile([])

        XCTAssertEqual(changes.count, 1)
        guard case .lost(let peer) = changes[0] else {
            return XCTFail("Expected a lost change")
        }
        XCTAssertEqual(peer.roleHint, .iPhone)
        XCTAssertEqual(peer.trustState, .untrusted)
        XCTAssertTrue(registry.peers.isEmpty)
    }

    func testNearBridgeEventIsStructuredAndVersionedByPhase() throws {
        let event = NearBridgeEvent(
            timestamp: Date(timeIntervalSince1970: 123),
            phase: .nb1,
            deviceRole: .iPhone,
            category: .peerFound,
            state: "untrusted",
            peerReference: "ephemeral",
            humanReadableDetail: "Discovery is not authentication"
        )

        XCTAssertTrue(event.compactDescription.contains("[NB-1]"))
        XCTAssertTrue(event.compactDescription.contains("peerFound.untrusted"))
        XCTAssertNoThrow(try JSONEncoder().encode(event))
    }
}
