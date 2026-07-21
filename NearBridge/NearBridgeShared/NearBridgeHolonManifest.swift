import Foundation

public enum HolonManifestError: Error, Equatable, LocalizedError {
    case unsupportedManifestVersion
    case invalidIdentifier
    case invalidDisplayName
    case missingCapabilities
    case duplicateCapability
    case invalidCapabilityLimit
    case unsafeExecutionProfile

    public var errorDescription: String? {
        switch self {
        case .unsupportedManifestVersion: return "Holon manifest version is not supported"
        case .invalidIdentifier: return "Holon manifest contains an invalid stable identifier"
        case .invalidDisplayName: return "Holon manifest display metadata is invalid"
        case .missingCapabilities: return "Holon manifest must declare at least one capability"
        case .duplicateCapability: return "Holon manifest declares the same capability more than once"
        case .invalidCapabilityLimit: return "Holon capability limits are invalid"
        case .unsafeExecutionProfile: return "Holon execution profile grants an unsupported capability"
        }
    }
}

public enum HolonIsolationBoundary: String, Codable, Equatable, Sendable {
    case hostProcess
    case appSandboxedXPC
    case appSandboxedNetworkXPC
    case externalUnverified
    case remoteProvider
}

public enum HolonNetworkPolicy: String, Codable, Equatable, Sendable {
    case denied
    case approvedOpenAIResponsesAPI
    case externallyManaged
}

public enum HolonCredentialPolicy: String, Codable, Equatable, Sendable {
    case none
    case hostKeychainAPIKey
    case externallyManaged
}

public struct AdapterExecutionProfile: Codable, Equatable, Identifiable, Sendable {
    public let profileID: String
    public let isolationBoundary: HolonIsolationBoundary
    public let networkPolicy: HolonNetworkPolicy
    public let credentialPolicy: HolonCredentialPolicy
    public let allowsFileRead: Bool
    public let allowsFileWrite: Bool
    public let allowsCommandExecution: Bool
    public let allowsDynamicTools: Bool
    public let disclosure: String

    public var id: String { profileID }

    public init(
        profileID: String,
        isolationBoundary: HolonIsolationBoundary,
        networkPolicy: HolonNetworkPolicy,
        credentialPolicy: HolonCredentialPolicy,
        allowsFileRead: Bool = false,
        allowsFileWrite: Bool = false,
        allowsCommandExecution: Bool = false,
        allowsDynamicTools: Bool = false,
        disclosure: String
    ) {
        self.profileID = profileID
        self.isolationBoundary = isolationBoundary
        self.networkPolicy = networkPolicy
        self.credentialPolicy = credentialPolicy
        self.allowsFileRead = allowsFileRead
        self.allowsFileWrite = allowsFileWrite
        self.allowsCommandExecution = allowsCommandExecution
        self.allowsDynamicTools = allowsDynamicTools
        self.disclosure = disclosure
    }

    public static let boundedHostProcess = AdapterExecutionProfile(
        profileID: "org.holonia.execution.host-process.inert-text.v1",
        isolationBoundary: .hostProcess,
        networkPolicy: .denied,
        credentialPolicy: .none,
        disclosure: "Host process · no file, command, network, credential, or dynamic tool interface"
    )

    public static let sandboxedLocalModel = AdapterExecutionProfile(
        profileID: "org.holonia.execution.sandboxed-local-model.v1",
        isolationBoundary: .appSandboxedXPC,
        networkPolicy: .denied,
        credentialPolicy: .none,
        disclosure: "App-sandboxed XPC model runner · network, file, command, credential, and dynamic tools denied"
    )

    public static let openAIModelOnly = AdapterExecutionProfile(
        profileID: "org.holonia.execution.openai-model-only.v1",
        isolationBoundary: .appSandboxedNetworkXPC,
        networkPolicy: .approvedOpenAIResponsesAPI,
        credentialPolicy: .hostKeychainAPIKey,
        disclosure: "Explicit OpenAI Responses API egress · model-only text · no files, commands, workspace, or tools"
    )

    public func validateForCurrentPlatform() throws {
        guard Self.isStableIdentifier(profileID), !disclosure.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HolonManifestError.invalidIdentifier
        }
        guard !allowsFileRead, !allowsFileWrite, !allowsCommandExecution, !allowsDynamicTools else {
            throw HolonManifestError.unsafeExecutionProfile
        }
        switch (networkPolicy, credentialPolicy, isolationBoundary) {
        case (.denied, .none, .hostProcess),
             (.denied, .none, .appSandboxedXPC),
             (.approvedOpenAIResponsesAPI, .hostKeychainAPIKey, .appSandboxedNetworkXPC),
             (.externallyManaged, .externallyManaged, .externalUnverified):
            return
        default:
            throw HolonManifestError.unsafeExecutionProfile
        }
    }

    static func isStableIdentifier(_ value: String) -> Bool {
        guard (3...200).contains(value.count), !value.hasPrefix("."), !value.hasSuffix(".") else { return false }
        return value.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0) || $0 == "." || $0 == "-"
        }
    }
}

public struct HolonCapabilityManifest: Codable, Equatable, Identifiable, Sendable {
    public let capabilityID: String
    public let displayName: String
    public let inputSchemaID: String
    public let outputSchemaID: String
    public let maximumInputCharacters: Int
    public let maximumOutputCharacters: Int

    public var id: String { capabilityID }

    public init(
        capabilityID: String,
        displayName: String,
        inputSchemaID: String = "org.holonia.schema.inert-text.v1",
        outputSchemaID: String = "org.holonia.schema.inert-text-result.v1",
        maximumInputCharacters: Int,
        maximumOutputCharacters: Int
    ) {
        self.capabilityID = capabilityID
        self.displayName = displayName
        self.inputSchemaID = inputSchemaID
        self.outputSchemaID = outputSchemaID
        self.maximumInputCharacters = maximumInputCharacters
        self.maximumOutputCharacters = maximumOutputCharacters
    }

    public func validate() throws {
        guard AdapterExecutionProfile.isStableIdentifier(capabilityID),
              AdapterExecutionProfile.isStableIdentifier(inputSchemaID),
              AdapterExecutionProfile.isStableIdentifier(outputSchemaID) else {
            throw HolonManifestError.invalidIdentifier
        }
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              displayName.count <= 120 else {
            throw HolonManifestError.invalidDisplayName
        }
        guard (1...16_000).contains(maximumInputCharacters),
              (1...16_000).contains(maximumOutputCharacters) else {
            throw HolonManifestError.invalidCapabilityLimit
        }
    }
}

public struct HolonManifest: Codable, Equatable, Identifiable, Sendable {
    public static let supportedManifestVersion = 1

    public let manifestVersion: Int
    public let implementationID: String
    public let vendorID: String
    public let displayName: String
    public let adapterLabel: String
    public let runtimeLabel: String
    public let modelDisclosure: String
    public let capabilities: [HolonCapabilityManifest]
    public let executionProfile: AdapterExecutionProfile

    public var id: String { implementationID }

    public init(
        manifestVersion: Int = HolonManifest.supportedManifestVersion,
        implementationID: String,
        vendorID: String,
        displayName: String,
        adapterLabel: String,
        runtimeLabel: String,
        modelDisclosure: String,
        capabilities: [HolonCapabilityManifest],
        executionProfile: AdapterExecutionProfile
    ) {
        self.manifestVersion = manifestVersion
        self.implementationID = implementationID
        self.vendorID = vendorID
        self.displayName = displayName
        self.adapterLabel = adapterLabel
        self.runtimeLabel = runtimeLabel
        self.modelDisclosure = modelDisclosure
        self.capabilities = capabilities
        self.executionProfile = executionProfile
    }

    public func validate() throws {
        guard manifestVersion == Self.supportedManifestVersion else {
            throw HolonManifestError.unsupportedManifestVersion
        }
        guard AdapterExecutionProfile.isStableIdentifier(implementationID),
              AdapterExecutionProfile.isStableIdentifier(vendorID),
              AdapterExecutionProfile.isStableIdentifier(runtimeLabel) else {
            throw HolonManifestError.invalidIdentifier
        }
        for value in [displayName, adapterLabel, modelDisclosure] {
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, value.count <= 300 else {
                throw HolonManifestError.invalidDisplayName
            }
        }
        guard !capabilities.isEmpty else { throw HolonManifestError.missingCapabilities }
        guard Set(capabilities.map(\.capabilityID)).count == capabilities.count else {
            throw HolonManifestError.duplicateCapability
        }
        try capabilities.forEach { try $0.validate() }
        try executionProfile.validateForCurrentPlatform()
    }

    public func capability(id: String) -> HolonCapabilityManifest? {
        capabilities.first { $0.capabilityID == id }
    }

    public func canonicalData() throws -> Data {
        try validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}

public struct HolonCapabilityRegistration: Equatable, Identifiable, Sendable {
    public let implementationID: String
    public let capability: HolonCapabilityManifest
    public let executionProfile: AdapterExecutionProfile

    public var id: String { capability.capabilityID }
}

public struct HolonCapabilityRegistry: Equatable, Sendable {
    private let registrationsByCapabilityID: [String: HolonCapabilityRegistration]

    public init(manifests: [HolonManifest]) throws {
        var registrations: [String: HolonCapabilityRegistration] = [:]
        for manifest in manifests {
            try manifest.validate()
            for capability in manifest.capabilities {
                guard registrations[capability.capabilityID] == nil else {
                    throw HolonManifestError.duplicateCapability
                }
                registrations[capability.capabilityID] = HolonCapabilityRegistration(
                    implementationID: manifest.implementationID,
                    capability: capability,
                    executionProfile: manifest.executionProfile
                )
            }
        }
        registrationsByCapabilityID = registrations
    }

    public var registrations: [HolonCapabilityRegistration] {
        registrationsByCapabilityID.values.sorted { $0.capability.capabilityID < $1.capability.capabilityID }
    }

    public func registration(capabilityID: String) -> HolonCapabilityRegistration? {
        registrationsByCapabilityID[capabilityID]
    }
}
