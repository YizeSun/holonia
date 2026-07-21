import Foundation
import NaturalLanguage

public enum PrimaryHolonImplementationID {
    public static let appleFoundationModel = "org.holonia.primary-holon.apple-foundation-model.v1"
    public static let appleNaturalLanguage = "org.holonia.primary-holon.apple-natural-language.v1"
    public static let deterministicDemo = "org.holonia.primary-holon.deterministic-demo.v1"
}

public enum PrimaryHolonRuntime: String, Codable, Equatable, Sendable {
    case appleFoundationModels
    case appleNaturalLanguage
    case deterministicSwift
}

public struct PrimaryHolonDescriptor: Codable, Equatable, Identifiable, Sendable {
    public let implementationID: String
    public let displayName: String
    public let adapterLabel: String
    public let runtime: PrimaryHolonRuntime
    public let modelDisclosure: String
    public let capability: NearBridgeCapabilityDescriptor
    public let executionProfile: AdapterExecutionProfile

    public var id: String { implementationID }
    public var usesRealModel: Bool { runtime != .deterministicSwift }

    public init(
        implementationID: String,
        displayName: String,
        adapterLabel: String,
        runtime: PrimaryHolonRuntime,
        modelDisclosure: String,
        capability: NearBridgeCapabilityDescriptor,
        executionProfile: AdapterExecutionProfile = .boundedHostProcess
    ) {
        self.implementationID = implementationID
        self.displayName = displayName
        self.adapterLabel = adapterLabel
        self.runtime = runtime
        self.modelDisclosure = modelDisclosure
        self.capability = capability
        self.executionProfile = executionProfile
    }
}

public struct HolonTextRequest: Equatable, Sendable {
    public let text: String

    public init(text: String) {
        self.text = text
    }
}

public struct HolonTextResult: Equatable, Sendable {
    public let text: String

    public init(text: String) {
        self.text = text
    }
}

/// The Primary Holon adapter boundary is intentionally narrower than a general Agent API.
/// It accepts inert text and returns inert text; no Host service, file, network,
/// process, identity key, or dynamic tool is exposed through this interface.
public protocol HolonAdapter: Sendable {
    var manifest: HolonManifest { get }
    var descriptor: PrimaryHolonDescriptor { get }
    func execute(_ request: HolonTextRequest) async throws -> HolonTextResult
}

public extension HolonAdapter {
    var descriptor: PrimaryHolonDescriptor {
        let capability = manifest.capabilities[0]
        return PrimaryHolonDescriptor(
            implementationID: manifest.implementationID,
            displayName: manifest.displayName,
            adapterLabel: manifest.adapterLabel,
            runtime: primaryHolonRuntime,
            modelDisclosure: manifest.modelDisclosure,
            capability: NearBridgeCapabilityDescriptor(
                capabilityID: capability.capabilityID,
                displayName: capability.displayName,
                executorLabel: manifest.adapterLabel,
                maximumInputCharacters: capability.maximumInputCharacters,
                maximumOutputCharacters: capability.maximumOutputCharacters
            ),
            executionProfile: manifest.executionProfile
        )
    }

    private var primaryHolonRuntime: PrimaryHolonRuntime {
        PrimaryHolonRuntime(rawValue: manifest.runtimeLabel) ?? .deterministicSwift
    }
}

public struct AppleNaturalLanguageHolonAdapter: HolonAdapter {
    public let manifest = HolonManifest(
        implementationID: PrimaryHolonImplementationID.appleNaturalLanguage,
        vendorID: "org.holonia",
        displayName: "Apple Natural Language",
        adapterLabel: "AppleNaturalLanguageHolonAdapter",
        runtimeLabel: PrimaryHolonRuntime.appleNaturalLanguage.rawValue,
        modelDisclosure: "Apple on-device language and sentiment models; no cloud request",
        capabilities: [HolonCapabilityManifest(
            capabilityID: ContactDemoCapability.primaryHolonTextInsight,
            displayName: "Primary Holon text insight",
            maximumInputCharacters: 1_200,
            maximumOutputCharacters: 280
        )],
        executionProfile: .boundedHostProcess
    )

    public init() {}

    public func execute(_ request: HolonTextRequest) async throws -> HolonTextResult {
        let input = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { throw CapabilityError.invalidInput }
        guard input.count <= descriptor.capability.maximumInputCharacters else {
            throw CapabilityError.inputTooLarge
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(input)
        let hypothesis = recognizer.languageHypotheses(withMaximum: 1).max { $0.value < $1.value }
        let language = hypothesis?.key.rawValue ?? "undetermined"
        let confidence = hypothesis.map { Int(($0.value * 100).rounded()) }
        let languageResult = confidence.map { "language: \(language) (\($0)%)" } ?? "language: \(language)"

        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = input
        let sentimentTag = tagger.tag(at: input.startIndex, unit: .paragraph, scheme: .sentimentScore).0
        let sentimentResult: String
        if let rawValue = sentimentTag?.rawValue, let score = Double(rawValue) {
            let label = score > 0.1 ? "positive" : (score < -0.1 ? "negative" : "neutral")
            sentimentResult = String(format: "sentiment: %@ (%.2f)", label, score)
        } else {
            sentimentResult = "sentiment: unavailable"
        }

        let output = "Apple on-device model · \(languageResult) · \(sentimentResult)"
        guard output.count <= descriptor.capability.maximumOutputCharacters else {
            throw CapabilityError.outputTooLarge
        }
        return HolonTextResult(text: output)
    }
}

public struct DeterministicDemoHolonAdapter: HolonAdapter {
    public let manifest = HolonManifest(
        implementationID: PrimaryHolonImplementationID.deterministicDemo,
        vendorID: "org.holonia",
        displayName: "Deterministic summary demo",
        adapterLabel: "DeterministicDemoHolonAdapter",
        runtimeLabel: PrimaryHolonRuntime.deterministicSwift.rawValue,
        modelDisclosure: "Deterministic Swift fallback; no model is used",
        capabilities: [HolonCapabilityManifest(
            capabilityID: ContactDemoCapability.primaryHolonTextInsight,
            displayName: "Primary Holon text insight",
            maximumInputCharacters: 1_200,
            maximumOutputCharacters: 280
        )],
        executionProfile: .boundedHostProcess
    )

    public init() {}

    public func execute(_ request: HolonTextRequest) async throws -> HolonTextResult {
        let summary = try await LocalSummaryAgent().execute(input: request.text)
        return HolonTextResult(text: summary)
    }
}

public struct AppleFoundationModelHolonAdapter: HolonAdapter {
    public let manifest = HolonManifest(
        implementationID: PrimaryHolonImplementationID.appleFoundationModel,
        vendorID: "org.holonia",
        displayName: "Apple Foundation Models (sandboxed)",
        adapterLabel: "AppleFoundationModelHolonAdapter",
        runtimeLabel: PrimaryHolonRuntime.appleFoundationModels.rawValue,
        modelDisclosure: "Apple on-device generative model through an app-sandboxed XPC runner; no tools or network",
        capabilities: [HolonCapabilityManifest(
            capabilityID: ContactDemoCapability.primaryHolonTextInsight,
            displayName: "Primary Holon inert-text answer",
            maximumInputCharacters: 1_200,
            maximumOutputCharacters: 1_200
        )],
        executionProfile: .sandboxedLocalModel
    )

    private let runner: any SandboxedModelRunning

    public init(runner: any SandboxedModelRunning = XPCSandboxedModelRunner()) {
        self.runner = runner
    }

    public func execute(_ request: HolonTextRequest) async throws -> HolonTextResult {
        let input = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { throw CapabilityError.invalidInput }
        guard input.count <= descriptor.capability.maximumInputCharacters else {
            throw CapabilityError.inputTooLarge
        }
        let response = try await runner.generate(SandboxedModelRequest(
            prompt: input,
            maximumOutputCharacters: descriptor.capability.maximumOutputCharacters,
            maximumResponseTokens: 384
        ))
        guard response.text.count <= descriptor.capability.maximumOutputCharacters else {
            throw CapabilityError.outputTooLarge
        }
        return HolonTextResult(text: response.text)
    }
}

struct PrimaryHolonCatalog {
    private let adaptersByID: [String: any HolonAdapter]

    init(adapters: [any HolonAdapter]) {
        for adapter in adapters {
            precondition((try? adapter.manifest.validate()) != nil, "Invalid built-in Holon manifest")
        }
        adaptersByID = Dictionary(
            adapters.map { ($0.descriptor.implementationID, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
    }

    static func standard() -> PrimaryHolonCatalog {
        PrimaryHolonCatalog(adapters: [
            AppleFoundationModelHolonAdapter(),
            AppleNaturalLanguageHolonAdapter(),
            DeterministicDemoHolonAdapter()
        ])
    }

    var descriptors: [PrimaryHolonDescriptor] {
        adaptersByID.values.map(\.descriptor).sorted { $0.displayName < $1.displayName }
    }

    var capabilityRegistry: HolonCapabilityRegistry {
        // Built-in manifests are validated during catalog construction.
        try! HolonCapabilityRegistry(manifests: adaptersByID.values.map(\.manifest))
    }

    func adapter(implementationID: String) -> (any HolonAdapter)? {
        adaptersByID[implementationID]
    }

    func defaultAdapter() -> any HolonAdapter {
        adaptersByID[PrimaryHolonImplementationID.appleFoundationModel] ?? AppleFoundationModelHolonAdapter()
    }
}

struct PrimaryHolonSelectionStore {
    static let selectionKey = "org.holonia.nearbridge.primary-holon-implementation"

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = selectionKey) {
        self.defaults = defaults
        self.key = key
    }

    func load(catalog: PrimaryHolonCatalog) -> any HolonAdapter {
        if let storedID = defaults.string(forKey: key), let adapter = catalog.adapter(implementationID: storedID) {
            return adapter
        }
        return catalog.defaultAdapter()
    }

    func save(implementationID: String, catalog: PrimaryHolonCatalog) throws {
        guard catalog.adapter(implementationID: implementationID) != nil else {
            throw CapabilityError.notRegistered
        }
        defaults.set(implementationID, forKey: key)
    }
}
