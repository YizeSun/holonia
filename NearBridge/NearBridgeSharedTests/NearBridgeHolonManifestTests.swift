import XCTest
@testable import NearBridgeShared

final class NearBridgeHolonManifestTests: XCTestCase {
    func testBuiltInManifestRoundTripsThroughCanonicalJSON() throws {
        let manifest = AppleNaturalLanguageHolonAdapter().manifest

        let data = try manifest.canonicalData()
        let decoded = try JSONDecoder().decode(HolonManifest.self, from: data)

        XCTAssertEqual(decoded, manifest)
        XCTAssertEqual(decoded.manifestVersion, HolonManifest.supportedManifestVersion)
        XCTAssertEqual(decoded.executionProfile, .boundedHostProcess)
        XCTAssertFalse(decoded.executionProfile.allowsFileRead)
        XCTAssertFalse(decoded.executionProfile.allowsCommandExecution)
        XCTAssertEqual(decoded.executionProfile.networkPolicy, .denied)
    }

    func testCapabilityRegistryMapsStableCapabilityToImplementationAndProfile() throws {
        let manifest = AppleNaturalLanguageHolonAdapter().manifest
        let registry = try HolonCapabilityRegistry(manifests: [manifest])
        let registration = try XCTUnwrap(
            registry.registration(capabilityID: ContactDemoCapability.primaryHolonTextInsight)
        )

        XCTAssertEqual(registration.implementationID, manifest.implementationID)
        XCTAssertEqual(registration.capability.inputSchemaID, "org.holonia.schema.inert-text.v1")
        XCTAssertEqual(registration.executionProfile.networkPolicy, .denied)
        XCTAssertNil(registry.registration(capabilityID: "arbitrary.shell"))
    }

    func testRegistryRejectsDuplicateCapabilityAcrossImplementations() throws {
        let original = AppleNaturalLanguageHolonAdapter().manifest
        let duplicate = HolonManifest(
            implementationID: "org.example.duplicate.v1",
            vendorID: "org.example",
            displayName: "Duplicate",
            adapterLabel: "DuplicateAdapter",
            runtimeLabel: "deterministicSwift",
            modelDisclosure: "Test only",
            capabilities: original.capabilities,
            executionProfile: .boundedHostProcess
        )

        XCTAssertThrowsError(try HolonCapabilityRegistry(manifests: [original, duplicate])) {
            XCTAssertEqual($0 as? HolonManifestError, .duplicateCapability)
        }
    }

    func testCurrentProfilesRejectFileCommandAndDynamicToolGrants() {
        let unsafe = AdapterExecutionProfile(
            profileID: "org.example.unsafe.v1",
            isolationBoundary: .hostProcess,
            networkPolicy: .denied,
            credentialPolicy: .none,
            allowsFileRead: true,
            allowsCommandExecution: true,
            allowsDynamicTools: true,
            disclosure: "Unsafe test profile"
        )

        XCTAssertThrowsError(try unsafe.validateForCurrentPlatform()) {
            XCTAssertEqual($0 as? HolonManifestError, .unsafeExecutionProfile)
        }
    }

    func testOpenAIProfileRequiresNetworkXPCAndHostKeychainWithoutTools() throws {
        let profile = AdapterExecutionProfile.openAIModelOnly

        XCTAssertNoThrow(try profile.validateForCurrentPlatform())
        XCTAssertEqual(profile.isolationBoundary, .appSandboxedNetworkXPC)
        XCTAssertEqual(profile.networkPolicy, .approvedOpenAIResponsesAPI)
        XCTAssertEqual(profile.credentialPolicy, .hostKeychainAPIKey)
        XCTAssertFalse(profile.allowsFileRead)
        XCTAssertFalse(profile.allowsFileWrite)
        XCTAssertFalse(profile.allowsCommandExecution)
        XCTAssertFalse(profile.allowsDynamicTools)
    }

    func testManifestRejectsInvalidVersionAndEmptyCapabilities() {
        let manifest = HolonManifest(
            manifestVersion: 999,
            implementationID: "org.example.invalid.v1",
            vendorID: "org.example",
            displayName: "Invalid",
            adapterLabel: "InvalidAdapter",
            runtimeLabel: "invalidRuntime",
            modelDisclosure: "Test only",
            capabilities: [],
            executionProfile: .boundedHostProcess
        )

        XCTAssertThrowsError(try manifest.validate()) {
            XCTAssertEqual($0 as? HolonManifestError, .unsupportedManifestVersion)
        }
    }
}
