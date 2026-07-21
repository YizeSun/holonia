import Foundation
import NaturalLanguage

public enum PrimaryHolonImplementationID {
    public static let appleNaturalLanguage = "org.holonia.primary-holon.apple-natural-language.v1"
    public static let deterministicDemo = "org.holonia.primary-holon.deterministic-demo.v1"
}

public enum PrimaryHolonRuntime: String, Codable, Equatable, Sendable {
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

    public var id: String { implementationID }
    public var usesRealModel: Bool { runtime == .appleNaturalLanguage }

    public init(
        implementationID: String,
        displayName: String,
        adapterLabel: String,
        runtime: PrimaryHolonRuntime,
        modelDisclosure: String,
        capability: NearBridgeCapabilityDescriptor
    ) {
        self.implementationID = implementationID
        self.displayName = displayName
        self.adapterLabel = adapterLabel
        self.runtime = runtime
        self.modelDisclosure = modelDisclosure
        self.capability = capability
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

/// The NB-6 adapter boundary is intentionally narrower than a general Agent API.
/// It accepts inert text and returns inert text; no Host service, file, network,
/// process, identity key, or dynamic tool is exposed through this interface.
public protocol HolonAdapter: Sendable {
    var descriptor: PrimaryHolonDescriptor { get }
    func execute(_ request: HolonTextRequest) throws -> HolonTextResult
}

public struct AppleNaturalLanguageHolonAdapter: HolonAdapter {
    public let descriptor = PrimaryHolonDescriptor(
        implementationID: PrimaryHolonImplementationID.appleNaturalLanguage,
        displayName: "Apple Natural Language",
        adapterLabel: "AppleNaturalLanguageHolonAdapter",
        runtime: .appleNaturalLanguage,
        modelDisclosure: "Apple on-device language and sentiment models; no cloud request",
        capability: NearBridgeCapabilityDescriptor(
            capabilityID: ContactDemoCapability.primaryHolonTextInsight,
            displayName: "Primary Holon text insight",
            executorLabel: "AppleNaturalLanguageHolonAdapter (on-device model)",
            maximumInputCharacters: 1_200,
            maximumOutputCharacters: 280
        )
    )

    public init() {}

    public func execute(_ request: HolonTextRequest) throws -> HolonTextResult {
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
    public let descriptor = PrimaryHolonDescriptor(
        implementationID: PrimaryHolonImplementationID.deterministicDemo,
        displayName: "Deterministic summary demo",
        adapterLabel: "DeterministicDemoHolonAdapter",
        runtime: .deterministicSwift,
        modelDisclosure: "Deterministic Swift fallback; no model is used",
        capability: NearBridgeCapabilityDescriptor(
            capabilityID: ContactDemoCapability.primaryHolonTextInsight,
            displayName: "Primary Holon text insight",
            executorLabel: "DeterministicDemoHolonAdapter (no model)",
            maximumInputCharacters: 1_200,
            maximumOutputCharacters: 280
        )
    )

    public init() {}

    public func execute(_ request: HolonTextRequest) throws -> HolonTextResult {
        let summary = try LocalSummaryAgent().execute(input: request.text)
        return HolonTextResult(text: summary)
    }
}

struct PrimaryHolonCatalog {
    private let adaptersByID: [String: any HolonAdapter]

    init(adapters: [any HolonAdapter]) {
        adaptersByID = Dictionary(
            adapters.map { ($0.descriptor.implementationID, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
    }

    static func standard() -> PrimaryHolonCatalog {
        PrimaryHolonCatalog(adapters: [
            AppleNaturalLanguageHolonAdapter(),
            DeterministicDemoHolonAdapter()
        ])
    }

    var descriptors: [PrimaryHolonDescriptor] {
        adaptersByID.values.map(\.descriptor).sorted { $0.displayName < $1.displayName }
    }

    func adapter(implementationID: String) -> (any HolonAdapter)? {
        adaptersByID[implementationID]
    }

    func defaultAdapter() -> any HolonAdapter {
        adaptersByID[PrimaryHolonImplementationID.appleNaturalLanguage] ?? AppleNaturalLanguageHolonAdapter()
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
