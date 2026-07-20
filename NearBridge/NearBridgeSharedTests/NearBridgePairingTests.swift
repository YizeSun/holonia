import CryptoKit
import XCTest
@testable import NearBridgeShared

final class NearBridgePairingTests: XCTestCase {
    func testStableIdentityDerivesSameNodeIDFromStoredKey() throws {
        let storedKey = P256.Signing.PrivateKey().rawRepresentation
        let first = try HostIdentityManager(privateKeyData: storedKey)
        let restored = try HostIdentityManager(privateKeyData: storedKey)

        let publicKey = try XCTUnwrap(Data(base64Encoded: first.identity.publicKeyBase64))
        XCTAssertEqual(first.identity, restored.identity)
        XCTAssertEqual(first.identity.nodeID, HostIdentityManager.nodeID(for: publicKey))
        XCTAssertEqual(first.identity.fingerprint.count, 12)
    }

    func testSignedHelloAndConfirmationRoundTrip() throws {
        let left = try HostIdentityManager.ephemeral()
        let right = try HostIdentityManager.ephemeral()
        let leftHello = try PairingProtocol.makeHello(
            identityManager: left,
            role: .iPhone,
            displayName: "Phone",
            nonce: Data(repeating: 1, count: 32)
        )
        let rightHello = try PairingProtocol.makeHello(
            identityManager: right,
            role: .mac,
            displayName: "Mac",
            nonce: Data(repeating: 2, count: 32)
        )

        XCTAssertNoThrow(try PairingProtocol.verify(leftHello))
        let leftHash = try PairingProtocol.transcriptHash(local: leftHello, remote: rightHello)
        let rightHash = try PairingProtocol.transcriptHash(local: rightHello, remote: leftHello)
        XCTAssertEqual(leftHash, rightHash)
        XCTAssertEqual(PairingProtocol.pairingCode(transcriptHash: leftHash).count, 6)

        let confirmation = try PairingProtocol.makeConfirmation(identityManager: right, transcriptHash: rightHash)
        XCTAssertNoThrow(try PairingProtocol.verify(confirmation, expectedTranscriptHash: leftHash, peerHello: rightHello))

        let encoded = try PairingProtocol.encode(.init(kind: .hello, hello: leftHello))
        XCTAssertEqual(try PairingProtocol.decode(encoded).hello, leftHello)
    }

    func testTamperedHelloIsRejected() throws {
        let manager = try HostIdentityManager.ephemeral()
        let hello = try PairingProtocol.makeHello(
            identityManager: manager,
            role: .mac,
            displayName: "Mac",
            nonce: Data(repeating: 3, count: 32)
        )
        let tampered = PairingHello(
            nodeID: hello.nodeID,
            publicKeyBase64: hello.publicKeyBase64,
            displayName: "Impostor",
            role: hello.role,
            nonceBase64: hello.nonceBase64,
            signatureBase64: hello.signatureBase64
        )

        XCTAssertThrowsError(try PairingProtocol.verify(tampered)) { error in
            XCTAssertEqual(error as? PairingProtocolError, .invalidSignature)
        }
    }

    func testStrangerCannotBecomePairedWithoutLocalApproval() {
        var machine = NearBridgePairingStateMachine()
        machine.receiveVerifiedHello()
        machine.receiveVerifiedConfirmation()

        XCTAssertEqual(machine.state, .awaitingLocalApproval)
        XCTAssertFalse(machine.localApproved)
        XCTAssertNotEqual(machine.state, .established)

        machine.approveLocally()
        XCTAssertEqual(machine.state, .established)
    }

    func testPairingCanBeRevokedLocally() {
        let record = PairedNodeRecord(
            nodeID: "node-a",
            displayName: "Mac",
            role: .mac,
            publicKeyBase64: "public"
        )
        var registry = NearBridgeTrustRegistry()
        registry.trust(record)
        XCTAssertTrue(registry.contains(nodeID: record.nodeID))

        XCTAssertEqual(registry.revoke(nodeID: record.nodeID), record)
        XCTAssertFalse(registry.contains(nodeID: record.nodeID))
    }
}
