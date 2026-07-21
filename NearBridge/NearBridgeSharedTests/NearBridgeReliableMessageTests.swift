import XCTest
@testable import NearBridgeShared

final class NearBridgeReliableMessageTests: XCTestCase {
    func testSignedPingPongAndAcknowledgementRoundTrip() throws {
        let phone = try HostIdentityManager.ephemeral()
        let mac = try HostIdentityManager.ephemeral()
        let now: Int64 = 1_000_000
        let sessionID = "fresh-session"
        let ping = try ReliableMessageCodec.makePing(
            sequence: 7,
            sessionID: sessionID,
            identityManager: phone,
            nowMilliseconds: now
        )
        let pong = try ReliableMessageCodec.makePong(
            for: ping,
            sessionID: sessionID,
            identityManager: mac,
            nowMilliseconds: now + 1
        )
        let acknowledgement = try ReliableMessageCodec.makeAcknowledgement(
            for: pong,
            sessionID: sessionID,
            identityManager: phone,
            nowMilliseconds: now + 2
        )

        XCTAssertEqual(ping.correlationID, ping.messageID)
        XCTAssertEqual(pong.correlationID, ping.messageID)
        XCTAssertEqual(acknowledgement.correlationID, pong.messageID)
        XCTAssertEqual(try ReliableMessageCodec.decode(ReliableMessageCodec.encode(ping)), ping)
        XCTAssertNoThrow(try ReliableMessageCodec.verifySignature(ping, publicKeyBase64: phone.identity.publicKeyBase64))
        XCTAssertNoThrow(try ReliableMessageCodec.verifySignature(pong, publicKeyBase64: mac.identity.publicKeyBase64))
    }

    func testValidatorAuthenticatesExpectedSenderAndIgnoresDuplicate() throws {
        let sender = try HostIdentityManager.ephemeral()
        let now: Int64 = 2_000_000
        let message = try ReliableMessageCodec.makePing(
            sequence: 1,
            sessionID: "session-a",
            identityManager: sender,
            nowMilliseconds: now
        )
        var validator = ReliableMessageValidator(
            expectedSenderNodeID: sender.identity.nodeID,
            expectedSessionID: "session-a",
            publicKeyBase64: sender.identity.publicKeyBase64
        )

        XCTAssertEqual(try validator.validate(message, nowMilliseconds: now + 1), .accepted(message))
        XCTAssertEqual(try validator.validate(message, nowMilliseconds: now + 1), .duplicateIgnored(message.messageID))
    }

    func testValidatorRejectsWrongSenderSessionExpiryAndFutureTimestamp() throws {
        let sender = try HostIdentityManager.ephemeral()
        let now: Int64 = 3_000_000
        let message = try ReliableMessageCodec.makePing(
            sequence: 1,
            sessionID: "session-a",
            identityManager: sender,
            nowMilliseconds: now,
            lifetimeMilliseconds: 1_000
        )

        var wrongSender = ReliableMessageValidator(
            expectedSenderNodeID: "stranger",
            expectedSessionID: "session-a",
            publicKeyBase64: sender.identity.publicKeyBase64
        )
        XCTAssertThrowsError(try wrongSender.validate(message, nowMilliseconds: now)) {
            XCTAssertEqual($0 as? ReliableMessageError, .unexpectedSender)
        }

        var wrongSession = ReliableMessageValidator(
            expectedSenderNodeID: sender.identity.nodeID,
            expectedSessionID: "session-b",
            publicKeyBase64: sender.identity.publicKeyBase64
        )
        XCTAssertThrowsError(try wrongSession.validate(message, nowMilliseconds: now)) {
            XCTAssertEqual($0 as? ReliableMessageError, .wrongSession)
        }

        var expired = ReliableMessageValidator(
            expectedSenderNodeID: sender.identity.nodeID,
            expectedSessionID: "session-a",
            publicKeyBase64: sender.identity.publicKeyBase64
        )
        XCTAssertThrowsError(try expired.validate(message, nowMilliseconds: now + 1_000)) {
            XCTAssertEqual($0 as? ReliableMessageError, .expired)
        }

        let future = try ReliableMessageCodec.makePing(
            sequence: 2,
            sessionID: "session-a",
            identityManager: sender,
            nowMilliseconds: now + 5_001
        )
        XCTAssertThrowsError(try expired.validate(future, nowMilliseconds: now)) {
            XCTAssertEqual($0 as? ReliableMessageError, .sentTooFarInFuture)
        }
    }

    func testTamperedPayloadFailsIntegrityVerification() throws {
        let sender = try HostIdentityManager.ephemeral()
        let message = try ReliableMessageCodec.makePing(
            sequence: 1,
            sessionID: "session-a",
            identityManager: sender,
            nowMilliseconds: 4_000_000
        )
        let tampered = NearBridgeReliableMessage(
            protocolName: message.protocolName,
            schemaVersion: message.schemaVersion,
            messageID: message.messageID,
            senderNodeID: message.senderNodeID,
            sessionID: message.sessionID,
            messageType: message.messageType,
            sentAtMilliseconds: message.sentAtMilliseconds,
            expiresAtMilliseconds: message.expiresAtMilliseconds,
            correlationID: message.correlationID,
            payload: .init(sequence: 999),
            signatureBase64: message.signatureBase64
        )

        XCTAssertThrowsError(try ReliableMessageCodec.verifySignature(tampered, publicKeyBase64: sender.identity.publicKeyBase64)) {
            XCTAssertEqual($0 as? ReliableMessageError, .invalidSignature)
        }
    }

    func testCapabilityResultSupportsBoundedModelAnswerAndRejectsOversize() throws {
        let phone = try HostIdentityManager.ephemeral()
        let mac = try HostIdentityManager.ephemeral()
        let invocation = try ReliableMessageCodec.makeCapabilityInvocation(
            input: "Question",
            sessionID: "session-model",
            identityManager: phone,
            nowMilliseconds: 5_000_000
        )
        let answer = String(repeating: "a", count: NearBridgeReliableMessage.maximumCapabilityResultCharacters)
        let result = try ReliableMessageCodec.makeCapabilityResult(
            for: invocation,
            output: answer,
            sessionID: "session-model",
            identityManager: mac,
            nowMilliseconds: 5_000_001
        )

        XCTAssertNoThrow(try ReliableMessageCodec.encode(result))

        let oversized = try ReliableMessageCodec.makeCapabilityResult(
            for: invocation,
            output: answer + "x",
            sessionID: "session-model",
            identityManager: mac,
            nowMilliseconds: 5_000_002
        )
        XCTAssertThrowsError(try ReliableMessageCodec.encode(oversized)) {
            XCTAssertEqual($0 as? ReliableMessageError, .invalidCorrelation)
        }
    }
}
