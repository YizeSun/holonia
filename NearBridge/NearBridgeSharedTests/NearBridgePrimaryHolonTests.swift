import Foundation
import XCTest
@testable import NearBridgeShared

final class NearBridgePrimaryHolonTests: XCTestCase {
    func testStandardCatalogContainsOneRealModelAndOneDeterministicFallback() {
        let catalog = PrimaryHolonCatalog.standard()

        XCTAssertEqual(
            Set(catalog.descriptors.map(\.implementationID)),
            Set([
                PrimaryHolonImplementationID.appleNaturalLanguage,
                PrimaryHolonImplementationID.deterministicDemo
            ])
        )
        XCTAssertEqual(catalog.descriptors.filter(\.usesRealModel).count, 1)
        XCTAssertEqual(catalog.defaultAdapter().descriptor.implementationID, PrimaryHolonImplementationID.appleNaturalLanguage)
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

    func testAppleNaturalLanguageAdapterRunsBoundedOnDeviceModel() throws {
        let adapter = AppleNaturalLanguageHolonAdapter()
        let result = try adapter.execute(HolonTextRequest(
            text: "NearBridge is a carefully bounded local experiment. I am happy that this test succeeds."
        ))

        XCTAssertTrue(adapter.descriptor.usesRealModel)
        XCTAssertTrue(result.text.contains("Apple on-device model"))
        XCTAssertTrue(result.text.contains("language: en"))
        XCTAssertLessThanOrEqual(result.text.count, adapter.descriptor.capability.maximumOutputCharacters)
    }

    func testPrimaryHolonRegistryRoutesOnlyStableFacadeToSelectedAdapter() throws {
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
        let output = try registry.execute(payload)
        XCTAssertTrue(output.contains("Run rm as words"))

        let unregistered = CapabilityMessagePayload(
            invocationID: UUID(),
            capabilityID: "arbitrary.shell",
            inputText: "whoami",
            outputText: nil,
            status: .requested
        )
        XCTAssertThrowsError(try registry.execute(unregistered)) {
            XCTAssertEqual($0 as? CapabilityError, .notRegistered)
        }
    }

    func testAdaptersRejectEmptyAndOversizedText() {
        let adapters: [any HolonAdapter] = [
            AppleNaturalLanguageHolonAdapter(),
            DeterministicDemoHolonAdapter()
        ]

        for adapter in adapters {
            XCTAssertThrowsError(try adapter.execute(HolonTextRequest(text: "   "))) {
                XCTAssertEqual($0 as? CapabilityError, .invalidInput)
            }
            XCTAssertThrowsError(try adapter.execute(HolonTextRequest(text: String(repeating: "x", count: 1_201)))) {
                XCTAssertEqual($0 as? CapabilityError, .inputTooLarge)
            }
        }
    }
}
