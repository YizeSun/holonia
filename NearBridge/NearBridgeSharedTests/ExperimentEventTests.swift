import XCTest
@testable import NearBridgeShared

final class ExperimentEventTests: XCTestCase {
    func testDiagnosticEventCapturesStructuredContext() throws {
        let error = NSError(domain: "NB0.Test", code: 42)
        let messageID = UUID()
        let event = ExperimentEvent(
            timestamp: Date(timeIntervalSince1970: 123),
            deviceRole: .iPhone,
            experiment: .bonjourNetwork,
            category: .frameworkError,
            state: "failed",
            peerReference: "ephemeral-peer",
            messageReference: messageID,
            durationMilliseconds: 12.5,
            error: error,
            humanReadableDetail: "Synthetic test failure"
        )

        XCTAssertEqual(event.errorDomain, "NB0.Test")
        XCTAssertEqual(event.errorCode, 42)
        XCTAssertEqual(event.messageReference, messageID)
        XCTAssertTrue(event.compactDescription.contains("frameworkError.failed"))
        XCTAssertNoThrow(try JSONEncoder().encode(event))
    }
}
