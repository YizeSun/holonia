import XCTest
@testable import NearBridgeShared

final class NearBridgeCapabilityTests: XCTestCase {
    func testMacRegistryContainsOnlyExplicitSummaryCapability() async throws {
        let registry = NearBridgeCapabilityRegistry.macNB5()
        XCTAssertEqual(registry.descriptors.map(\.capabilityID), [ContactDemoCapability.textSummarization])

        let payload = CapabilityMessagePayload(
            invocationID: UUID(),
            capabilityID: ContactDemoCapability.textSummarization,
            inputText: "First sentence explains the input. Second sentence adds context. Third sentence is omitted.",
            outputText: nil,
            status: .requested
        )
        let output = try await registry.execute(payload)
        XCTAssertEqual(output, "First sentence explains the input. Second sentence adds context")
    }

    func testUnregisteredCapabilityAndOversizedInputAreRejected() async {
        let registry = NearBridgeCapabilityRegistry.macNB5()
        let unknown = CapabilityMessagePayload(
            invocationID: UUID(),
            capabilityID: "arbitrary.command",
            inputText: "do something",
            outputText: nil,
            status: .requested
        )
        do {
            _ = try await registry.execute(unknown)
            XCTFail("Expected an unregistered capability error")
        } catch {
            XCTAssertEqual(error as? CapabilityError, .notRegistered)
        }

        let oversized = CapabilityMessagePayload(
            invocationID: UUID(),
            capabilityID: ContactDemoCapability.textSummarization,
            inputText: String(repeating: "x", count: 1_201),
            outputText: nil,
            status: .requested
        )
        do {
            _ = try await registry.execute(oversized)
            XCTFail("Expected an oversized input error")
        } catch {
            XCTAssertEqual(error as? CapabilityError, .inputTooLarge)
        }
    }

    func testCommandLikeTextIsSummarizedAsTextOnly() async throws {
        let registry = NearBridgeCapabilityRegistry.macNB5()
        let payload = CapabilityMessagePayload(
            invocationID: UUID(),
            capabilityID: ContactDemoCapability.textSummarization,
            inputText: "The text says to run a shell command. NearBridge must treat these words only as inert text.",
            outputText: nil,
            status: .requested
        )

        let output = try await registry.execute(payload)
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
