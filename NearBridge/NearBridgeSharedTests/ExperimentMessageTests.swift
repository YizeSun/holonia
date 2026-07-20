import XCTest
@testable import NearBridgeShared

final class ExperimentMessageTests: XCTestCase {
    func testPingRoundTripsThroughJSON() throws {
        let id = UUID(uuidString: "B515CF03-6DBF-4361-9E7E-873D174CFD47")!
        let ping = ExperimentMessage.ping(sequence: 7, now: Date(timeIntervalSince1970: 1_700_000_000), id: id)

        let decoded = try ExperimentMessageCodec.decode(ExperimentMessageCodec.encode(ping))

        XCTAssertEqual(decoded, ping)
        XCTAssertEqual(decoded.correlationID, decoded.messageID)
    }

    func testPongKeepsPingCorrelation() throws {
        let ping = ExperimentMessage.ping(sequence: 8)
        let pong = ExperimentMessage.pong(for: ping)
        let decoded = try ExperimentMessageCodec.decode(ExperimentMessageCodec.encode(pong))

        XCTAssertEqual(decoded.messageType, .pong)
        XCTAssertEqual(decoded.correlationID, ping.messageID)
        XCTAssertEqual(decoded.payload, ping.payload)
        XCTAssertNotEqual(decoded.messageID, ping.messageID)
    }

    func testUnsupportedSchemaIsRejected() throws {
        let invalid = ExperimentMessage(
            schemaVersion: 99,
            messageType: .ping,
            correlationID: UUID(),
            payload: .init(sequence: 1)
        )
        XCTAssertThrowsError(try ExperimentMessageCodec.encode(invalid)) { error in
            XCTAssertEqual(error as? ExperimentMessageError, .unsupportedSchemaVersion(99))
        }
    }

    func testMalformedJSONIsRejected() {
        XCTAssertThrowsError(try ExperimentMessageCodec.decode(Data("{not json".utf8))) { error in
            XCTAssertEqual(error as? ExperimentMessageError, .malformedMessage)
        }
    }

    func testInvalidPingCorrelationIsRejected() {
        let invalid = ExperimentMessage(
            messageType: .ping,
            correlationID: UUID(),
            payload: .init(sequence: 2)
        )
        XCTAssertThrowsError(try invalid.validate()) { error in
            XCTAssertEqual(error as? ExperimentMessageError, .invalidPingCorrelation)
        }
    }

    func testDuplicateTrackerRejectsSecondInsertion() {
        var tracker = MessageIdentifierTracker()
        let id = UUID()
        XCTAssertTrue(tracker.insert(id))
        XCTAssertFalse(tracker.insert(id))
    }
}
