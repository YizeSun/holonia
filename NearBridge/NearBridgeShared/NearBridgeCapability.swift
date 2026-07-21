import Foundation

public struct NearBridgeCapabilityDescriptor: Codable, Equatable, Identifiable, Sendable {
    public let capabilityID: String
    public let displayName: String
    public let executorLabel: String
    public let maximumInputCharacters: Int
    public let maximumOutputCharacters: Int

    public var id: String { capabilityID }

    public init(
        capabilityID: String,
        displayName: String,
        executorLabel: String,
        maximumInputCharacters: Int,
        maximumOutputCharacters: Int
    ) {
        self.capabilityID = capabilityID
        self.displayName = displayName
        self.executorLabel = executorLabel
        self.maximumInputCharacters = maximumInputCharacters
        self.maximumOutputCharacters = maximumOutputCharacters
    }
}

public enum CapabilityExecutionStatus: String, Codable, Equatable, Sendable {
    case requested
    case succeeded
    case failed
}

public struct CapabilityMessagePayload: Codable, Equatable, Sendable {
    public let invocationID: UUID
    public let capabilityID: String
    public let inputText: String?
    public let outputText: String?
    public let status: CapabilityExecutionStatus

    public init(
        invocationID: UUID,
        capabilityID: String,
        inputText: String?,
        outputText: String?,
        status: CapabilityExecutionStatus
    ) {
        self.invocationID = invocationID
        self.capabilityID = capabilityID
        self.inputText = inputText
        self.outputText = outputText
        self.status = status
    }
}

public enum CapabilityExecutionState: String, Codable, Equatable, Sendable {
    case idle
    case requestSent
    case executing
    case succeeded
    case failed
}

public enum CapabilityError: Error, Equatable, LocalizedError {
    case notRegistered
    case invalidInput
    case inputTooLarge
    case outputTooLarge
    case wrongRole
    case workflowNotCompleted
    case invalidMessage
    case correlationMismatch

    public var errorDescription: String? {
        switch self {
        case .notRegistered: return "Capability is not registered by this Host"
        case .invalidInput: return "Capability input must contain plain text"
        case .inputTooLarge: return "Capability input exceeds the registered limit"
        case .outputTooLarge: return "Capability output exceeds the registered limit"
        case .wrongRole: return "This capability is only registered on the Mac Host"
        case .workflowNotCompleted: return "Complete the contact flow before invoking the capability"
        case .invalidMessage: return "Capability message is invalid"
        case .correlationMismatch: return "Capability result does not match the pending invocation"
        }
    }
}

protocol NearBridgeCapabilityHandler {
    var descriptor: NearBridgeCapabilityDescriptor { get }
    func execute(input: String) throws -> String
}

struct PrimaryHolonCapabilityHandler: NearBridgeCapabilityHandler {
    let adapter: any HolonAdapter

    var descriptor: NearBridgeCapabilityDescriptor { adapter.descriptor.capability }

    func execute(input: String) throws -> String {
        try adapter.execute(HolonTextRequest(text: input)).text
    }
}

struct LocalSummaryAgent: NearBridgeCapabilityHandler {
    let descriptor = NearBridgeCapabilityDescriptor(
        capabilityID: ContactDemoCapability.textSummarization,
        displayName: "Extractive text summary",
        executorLabel: "LocalSummaryAgent (deterministic demo)",
        maximumInputCharacters: 1_200,
        maximumOutputCharacters: 280
    )

    func execute(input: String) throws -> String {
        let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw CapabilityError.invalidInput }
        guard normalized.count <= descriptor.maximumInputCharacters else { throw CapabilityError.inputTooLarge }

        let separators = CharacterSet(charactersIn: ".!?。！？\n")
        let sentences = normalized
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let selected = Array(sentences.prefix(2))
        let fallback = String(normalized.prefix(descriptor.maximumOutputCharacters))
        let summary = selected.isEmpty ? fallback : selected.joined(separator: ". ")
        let bounded = String(summary.prefix(descriptor.maximumOutputCharacters))
        guard !bounded.isEmpty else { throw CapabilityError.invalidInput }
        return bounded
    }
}

struct NearBridgeCapabilityRegistry {
    private let handlers: [String: any NearBridgeCapabilityHandler]

    init(handlers: [any NearBridgeCapabilityHandler]) {
        self.handlers = Dictionary(handlers.map { ($0.descriptor.capabilityID, $0) }, uniquingKeysWith: { _, latest in latest })
    }

    static func macNB5() -> NearBridgeCapabilityRegistry {
        NearBridgeCapabilityRegistry(handlers: [LocalSummaryAgent()])
    }

    static func macNB6(adapter: any HolonAdapter) -> NearBridgeCapabilityRegistry {
        NearBridgeCapabilityRegistry(handlers: [PrimaryHolonCapabilityHandler(adapter: adapter)])
    }

    static func empty() -> NearBridgeCapabilityRegistry {
        NearBridgeCapabilityRegistry(handlers: [])
    }

    var descriptors: [NearBridgeCapabilityDescriptor] {
        handlers.values.map(\.descriptor).sorted { $0.capabilityID < $1.capabilityID }
    }

    func execute(_ payload: CapabilityMessagePayload) throws -> String {
        guard payload.status == .requested, payload.outputText == nil, let input = payload.inputText else {
            throw CapabilityError.invalidMessage
        }
        guard let handler = handlers[payload.capabilityID] else { throw CapabilityError.notRegistered }
        guard input.count <= handler.descriptor.maximumInputCharacters else { throw CapabilityError.inputTooLarge }
        let output = try handler.execute(input: input)
        guard output.count <= handler.descriptor.maximumOutputCharacters else { throw CapabilityError.outputTooLarge }
        return output
    }
}
