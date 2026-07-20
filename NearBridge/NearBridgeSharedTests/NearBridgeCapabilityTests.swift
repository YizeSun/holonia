import XCTest
@testable import NearBridgeShared

final class NearBridgeCapabilityTests: XCTestCase {
    func testMacRegistryContainsOnlyExplicitSummaryCapability() throws {
        let registry = NearBridgeCapabilityRegistry.macNB5()
        XCTAssertEqual(registry.descriptors.map(\.capabilityID), [ContactDemoCapability.textSummarization])

        let payload = CapabilityMessagePayload(
            invocationID: UUID(),
            capabilityID: ContactDemoCapability.textSummarization,
            inputText: "First sentence explains the input. Second sentence adds context. Third sentence is omitted.",
            outputText: nil,
            status: .requested
        )
        XCTAssertEqual(
            try registry.execute(payload),
            "First sentence explains the input. Second sentence adds context"
        )
    }

    func testUnregisteredCapabilityAndOversizedInputAreRejected() {
        let registry = NearBridgeCapabilityRegistry.macNB5()
        let unknown = CapabilityMessagePayload(
            invocationID: UUID(),
            capabilityID: "arbitrary.command",
            inputText: "do something",
            outputText: nil,
            status: .requested
        )
        XCTAssertThrowsError(try registry.execute(unknown)) {
            XCTAssertEqual($0 as? CapabilityError, .notRegistered)
        }

        let oversized = CapabilityMessagePayload(
            invocationID: UUID(),
            capabilityID: ContactDemoCapability.textSummarization,
            inputText: String(repeating: "x", count: 1_201),
            outputText: nil,
            status: .requested
        )
        XCTAssertThrowsError(try registry.execute(oversized)) {
            XCTAssertEqual($0 as? CapabilityError, .inputTooLarge)
        }
    }

    func testCommandLikeTextIsSummarizedAsTextOnly() throws {
        let registry = NearBridgeCapabilityRegistry.macNB5()
        let payload = CapabilityMessagePayload(
            invocationID: UUID(),
            capabilityID: ContactDemoCapability.textSummarization,
            inputText: "The text says to run a shell command. NearBridge must treat these words only as inert text.",
            outputText: nil,
            status: .requested
        )

        let output = try registry.execute(payload)
        XCTAssertTrue(output.contains("shell command"))
        XCTAssertTrue(output.contains("inert text"))
    }

    func testSignedInvocationAndResultKeepTypedCorrelation() throws {
        let phone = try HostIdentityManager.ephemeral()
        let mac = try HostIdentityManager.ephemeral()
        let invocation = try ReliableMessageCodec.makeCapabilityInvocation(
            input: "One sentence. Another sentence.",
            sessionID: "nb5-session",
            identityManager: phone,
            nowMilliseconds: 5_000
        )
        let result = try ReliableMessageCodec.makeCapabilityResult(
            for: invocation,
            output: "One sentence. Another sentence",
            sessionID: "nb5-session",
            identityManager: mac,
            nowMilliseconds: 5_001
        )

        XCTAssertEqual(invocation.correlationID, invocation.messageID)
        XCTAssertEqual(result.correlationID, invocation.messageID)
        XCTAssertEqual(result.payload.capability?.invocationID, invocation.payload.capability?.invocationID)
        XCTAssertEqual(result.payload.capability?.status, .succeeded)
        XCTAssertNoThrow(try ReliableMessageCodec.encode(invocation))
        XCTAssertNoThrow(try ReliableMessageCodec.verifySignature(result, publicKeyBase64: mac.identity.publicKeyBase64))
    }
}
