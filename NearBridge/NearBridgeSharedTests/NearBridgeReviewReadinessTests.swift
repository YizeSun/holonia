import XCTest
@testable import NearBridgeShared

final class NearBridgeReviewReadinessTests: XCTestCase {
    func testReadinessOrdersReviewerActionsAndCompletes() {
        let blocked = NearBridgeReviewReadiness.items(for: .init(
            isRunning: true,
            localNetworkAccess: .available,
            peerCount: 1,
            sessionState: .idle,
            authenticationState: .idle,
            contactState: .idle,
            capabilityState: .idle,
            primaryHolonSelected: true,
            primaryHolonNeedsCredential: true,
            primaryHolonCredentialConfigured: false
        ))
        XCTAssertEqual(blocked.first?.state, .ready)
        XCTAssertEqual(blocked.first(where: { $0.id == "session" })?.state, .actionRequired)
        XCTAssertEqual(blocked.first(where: { $0.id == "implementation" })?.state, .actionRequired)
        XCTAssertTrue(NearBridgeReviewReadiness.nextAction(for: blocked).contains("Pair"))

        let complete = NearBridgeReviewReadiness.items(for: .init(
            isRunning: true,
            localNetworkAccess: .available,
            peerCount: 1,
            sessionState: .connected,
            authenticationState: .authenticated,
            contactState: .completed,
            capabilityState: .succeeded,
            primaryHolonSelected: true,
            primaryHolonNeedsCredential: true,
            primaryHolonCredentialConfigured: true
        ))
        XCTAssertEqual(NearBridgeReviewReadiness.progress(for: complete), 1)
        XCTAssertTrue(NearBridgeReviewReadiness.nextAction(for: complete).contains("Export"))
    }

    func testExecutionReceiptReportsLatencyAndAcknowledgement() {
        let started = Date(timeIntervalSince1970: 100)
        var receipt = NearBridgeExecutionReceipt(
            invocationID: UUID(),
            capabilityID: "capability.test.v1",
            providerLabel: "Test Primary Holon",
            peerFingerprint: "ABC123",
            startedAt: started,
            outcome: .requestSent,
            integrity: "signed"
        )
        receipt.completedAt = started.addingTimeInterval(0.125)
        receipt.outcome = .succeeded
        receipt.acknowledgement = .received

        XCTAssertEqual(receipt.latencyMilliseconds ?? 0, 125, accuracy: 0.001)
        XCTAssertEqual(receipt.outcome, .succeeded)
        XCTAssertEqual(receipt.acknowledgement, .received)
    }

    func testDiagnosticExportRedactsCredentialPatternsAndOmitsBodies() {
        let event = NearBridgeEvent(
            phase: .nb9,
            deviceRole: .mac,
            category: .frameworkError,
            state: "test",
            humanReadableDetail: "Authorization: Bearer secret-token sk-test-1234567890"
        )
        let exported = NearBridgeDiagnosticExport.make(
            phase: .nb9,
            role: .mac,
            readiness: [],
            receipt: nil,
            events: [event]
        )

        XCTAssertFalse(exported.contains("secret-token"))
        XCTAssertFalse(exported.contains("sk-test"))
        XCTAssertTrue(exported.contains("[REDACTED]"))
        XCTAssertTrue(exported.contains("Prompt and answer bodies are not included"))
    }

    func testSafetyIdentifierIsStableBoundedAndDoesNotExposeSession() {
        let first = NearBridgeSafetyIdentifier.forSession("private-session-A")
        let repeatValue = NearBridgeSafetyIdentifier.forSession("private-session-A")
        let second = NearBridgeSafetyIdentifier.forSession("private-session-B")

        XCTAssertEqual(first, repeatValue)
        XCTAssertNotEqual(first, second)
        XCTAssertTrue(first.hasPrefix("nb_"))
        XCTAssertLessThanOrEqual(first.count, 64)
        XCTAssertFalse(first.contains("private-session"))
    }
}
