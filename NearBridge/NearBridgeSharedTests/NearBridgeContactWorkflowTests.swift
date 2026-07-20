import XCTest
@testable import NearBridgeShared

final class NearBridgeContactWorkflowTests: XCTestCase {
    func testContactFlowMovesRequestResponseAcceptanceToCompletion() throws {
        let requesterIdentity = try HostIdentityManager.ephemeral()
        let providerIdentity = try HostIdentityManager.ephemeral()
        let sessionID = "contact-session"
        var requester = ContactWorkflowStateMachine()
        var provider = ContactWorkflowStateMachine()

        let request = try ReliableMessageCodec.makeContactRequest(
            sessionID: sessionID,
            identityManager: requesterIdentity,
            nowMilliseconds: 1_000
        )
        try requester.apply(request, direction: .sent)
        try provider.apply(request, direction: .received)
        XCTAssertEqual(requester.state, .requestSent)
        XCTAssertEqual(provider.state, .requestReceived)

        let response = try ReliableMessageCodec.makeCapabilityResponse(
            to: request,
            sessionID: sessionID,
            identityManager: providerIdentity,
            nowMilliseconds: 1_001
        )
        try provider.apply(response, direction: .sent)
        try requester.apply(response, direction: .received)
        XCTAssertEqual(requester.state, .responseReceived)
        XCTAssertEqual(provider.state, .responseSent)

        let accepted = try ReliableMessageCodec.makeContactAccepted(
            response: response,
            sessionID: sessionID,
            identityManager: requesterIdentity,
            nowMilliseconds: 1_002
        )
        try requester.apply(accepted, direction: .sent)
        try provider.apply(accepted, direction: .received)
        XCTAssertEqual(requester.state, .acceptanceSent)
        XCTAssertEqual(provider.state, .acceptanceReceived)

        let completed = try ReliableMessageCodec.makeContactCompleted(
            acceptance: accepted,
            sessionID: sessionID,
            identityManager: providerIdentity,
            nowMilliseconds: 1_003
        )
        try provider.apply(completed, direction: .sent)
        try requester.apply(completed, direction: .received)

        XCTAssertEqual(requester.state, .completed)
        XCTAssertEqual(provider.state, .completed)
        XCTAssertEqual(requester.requestID, provider.requestID)
        XCTAssertEqual(requester.responseID, provider.responseID)
        XCTAssertEqual(requester.capabilityID, ContactDemoCapability.textSummarization)
    }

    func testProviderCannotSkipRequestAndSendResponse() throws {
        let identity = try HostIdentityManager.ephemeral()
        let request = try ReliableMessageCodec.makeContactRequest(
            sessionID: "session",
            identityManager: identity,
            nowMilliseconds: 2_000
        )
        let response = try ReliableMessageCodec.makeCapabilityResponse(
            to: request,
            sessionID: "session",
            identityManager: identity,
            nowMilliseconds: 2_001
        )
        var workflow = ContactWorkflowStateMachine()

        XCTAssertThrowsError(try workflow.apply(response, direction: .sent)) {
            XCTAssertEqual($0 as? ContactWorkflowError, .wrongState)
        }
        XCTAssertEqual(workflow.state, .idle)
    }

    func testWrongCorrelationCannotAdvanceContactFlow() throws {
        let identity = try HostIdentityManager.ephemeral()
        let request = try ReliableMessageCodec.makeContactRequest(
            sessionID: "session",
            identityManager: identity,
            nowMilliseconds: 3_000
        )
        let response = try ReliableMessageCodec.makeCapabilityResponse(
            to: request,
            sessionID: "session",
            identityManager: identity,
            nowMilliseconds: 3_001
        )
        let invalid = NearBridgeReliableMessage(
            protocolName: response.protocolName,
            schemaVersion: response.schemaVersion,
            messageID: response.messageID,
            senderNodeID: response.senderNodeID,
            sessionID: response.sessionID,
            messageType: response.messageType,
            sentAtMilliseconds: response.sentAtMilliseconds,
            expiresAtMilliseconds: response.expiresAtMilliseconds,
            correlationID: UUID(),
            payload: response.payload,
            signatureBase64: response.signatureBase64
        )
        var requester = ContactWorkflowStateMachine()
        try requester.apply(request, direction: .sent)

        XCTAssertThrowsError(try requester.apply(invalid, direction: .received)) {
            XCTAssertEqual($0 as? ContactWorkflowError, .invalidCorrelation)
        }
        XCTAssertEqual(requester.state, .requestSent)
    }
}
