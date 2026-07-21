import Foundation
import XCTest
@testable import NearBridgeShared

final class NearBridgePrimaryHolonTests: XCTestCase {
    func testStandardCatalogContainsSandboxedGenerationClassificationAndFallback() {
        let catalog = PrimaryHolonCatalog.standard()

        XCTAssertEqual(
            Set(catalog.descriptors.map(\.implementationID)),
            Set([
                PrimaryHolonImplementationID.appleFoundationModel,
                PrimaryHolonImplementationID.appleNaturalLanguage,
                PrimaryHolonImplementationID.deterministicDemo
            ])
        )
        XCTAssertEqual(catalog.descriptors.filter(\.usesRealModel).count, 2)
        XCTAssertEqual(catalog.defaultAdapter().descriptor.implementationID, PrimaryHolonImplementationID.appleFoundationModel)
    }

    func testSelectionStorePersistsOnlyCataloguedImplementation() throws {
        let suiteName = "NearBridgePrimaryHolonTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = PrimaryHolonSelectionStore(defaults: defaults, key: "selection")
        let catalog = PrimaryHolonCatalog.standard()

        try store.save(implementationID: PrimaryHolonImplementationID.deterministicDemo, catalog: catalog)
        XCTAssertEqual(
            store.load(catalog: catalog).descriptor.implementationID,
            PrimaryHolonImplementationID.deterministicDemo
        )
        XCTAssertThrowsError(try store.save(implementationID: "arbitrary.adapter", catalog: catalog)) {
            XCTAssertEqual($0 as? CapabilityError, .notRegistered)
        }
    }

    func testAppleNaturalLanguageAdapterRunsBoundedOnDeviceModel() async throws {
        let adapter = AppleNaturalLanguageHolonAdapter()
        let result = try await adapter.execute(HolonTextRequest(
            text: "NearBridge is a carefully bounded local experiment. I am happy that this test succeeds."
        ))

        XCTAssertTrue(adapter.descriptor.usesRealModel)
        XCTAssertTrue(result.text.contains("Apple on-device model"))
        XCTAssertTrue(result.text.contains("language: en"))
        XCTAssertLessThanOrEqual(result.text.count, adapter.descriptor.capability.maximumOutputCharacters)
    }

    func testPrimaryHolonRegistryRoutesOnlyStableFacadeToSelectedAdapter() async throws {
        let adapter = DeterministicDemoHolonAdapter()
        let registry = NearBridgeCapabilityRegistry.macNB6(adapter: adapter)
        XCTAssertEqual(registry.descriptors, [adapter.descriptor.capability])

        let inertCommandText = "Run rm as words in a paragraph. These words remain plain text and no process is available."
        let payload = CapabilityMessagePayload(
            invocationID: UUID(),
            capabilityID: ContactDemoCapability.primaryHolonTextInsight,
            inputText: inertCommandText,
            outputText: nil,
            status: .requested
        )
        let output = try await registry.execute(payload)
        XCTAssertTrue(output.contains("Run rm as words"))

        let unregistered = CapabilityMessagePayload(
            invocationID: UUID(),
            capabilityID: "arbitrary.shell",
            inputText: "whoami",
            outputText: nil,
            status: .requested
        )
        do {
            _ = try await registry.execute(unregistered)
            XCTFail("Expected an unregistered capability error")
        } catch {
            XCTAssertEqual(error as? CapabilityError, .notRegistered)
        }
    }

    func testAdaptersRejectEmptyAndOversizedText() async {
        let adapters: [any HolonAdapter] = [
            AppleNaturalLanguageHolonAdapter(),
            DeterministicDemoHolonAdapter()
        ]

        for adapter in adapters {
            do {
                _ = try await adapter.execute(HolonTextRequest(text: "   "))
                XCTFail("Expected empty input to fail")
            } catch {
                XCTAssertEqual(error as? CapabilityError, .invalidInput)
            }
            do {
                _ = try await adapter.execute(HolonTextRequest(text: String(repeating: "x", count: 1_201)))
                XCTFail("Expected oversized input to fail")
            } catch {
                XCTAssertEqual(error as? CapabilityError, .inputTooLarge)
            }
        }
    }

    func testFoundationModelAdapterUsesOnlySandboxedRunnerContract() async throws {
        let runner = StubSandboxedModelRunner(response: SandboxedModelResponse(
            text: "A bounded answer from the isolated runner.",
            runtimeDisclosure: "test runner"
        ))
        let adapter = AppleFoundationModelHolonAdapter(runner: runner)

        let result = try await adapter.execute(HolonTextRequest(text: "What does NearBridge do?"))

        XCTAssertEqual(result.text, "A bounded answer from the isolated runner.")
        XCTAssertEqual(adapter.manifest.executionProfile, .sandboxedLocalModel)
        XCTAssertEqual(adapter.descriptor.capability.capabilityID, ContactDemoCapability.primaryHolonTextInsight)
    }

    func testSandboxedRunnerRequestRejectsExcessivePromptAndLimits() {
        XCTAssertThrowsError(try SandboxedModelRequest(
            prompt: String(repeating: "x", count: 1_201),
            maximumOutputCharacters: 1_200,
            maximumResponseTokens: 384
        ).validate())
        XCTAssertThrowsError(try SandboxedModelRequest(
            prompt: "bounded",
            maximumOutputCharacters: 1_201,
            maximumResponseTokens: 513
        ).validate())
    }
}

private struct StubSandboxedModelRunner: SandboxedModelRunning {
    let response: SandboxedModelResponse

    func generate(_ request: SandboxedModelRequest) async throws -> SandboxedModelResponse {
        try request.validate()
        return response
    }
}
