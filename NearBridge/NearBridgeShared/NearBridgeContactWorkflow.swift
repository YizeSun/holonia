import Foundation

public enum ContactDemoCapability {
    public static let codeProblemAnalysis = "holonia.contact.code-analysis.v1"
    public static let textSummarization = "holonia.capability.text-summary.extractive.v1"
    public static let defaultCapabilityID = textSummarization
    public static let requestSummary = "Find the explicitly registered local text-summary capability"
    public static let responseSummary = "The Host offers a narrow local summary Agent; it has not been invoked yet"
}

public struct ContactWorkflowPayload: Codable, Equatable, Sendable {
    public let requestID: UUID
    public let responseID: UUID?
    public let capabilityID: String
    public let summary: String

    public init(requestID: UUID, responseID: UUID?, capabilityID: String, summary: String) {
        self.requestID = requestID
        self.responseID = responseID
        self.capabilityID = capabilityID
        self.summary = summary
    }
}

public enum ContactWorkflowState: String, Codable, Equatable, Sendable {
    case idle
    case requestSent
    case requestReceived
    case responseSent
    case responseReceived
    case acceptanceSent
    case acceptanceReceived
    case completed
}

public enum ContactWorkflowDirection: Equatable, Sendable {
    case sent
    case received
}

public enum ContactWorkflowError: Error, Equatable, LocalizedError {
    case wrongState
    case missingPayload
    case invalidCapability
    case invalidSummary
    case invalidRequest
    case invalidResponse
    case invalidCorrelation

    public var errorDescription: String? {
        switch self {
        case .wrongState: return "Contact message is not valid in the current workflow state"
        case .missingPayload: return "Contact message payload is missing"
        case .invalidCapability: return "Contact capability identifier is invalid"
        case .invalidSummary: return "Contact summary is invalid"
        case .invalidRequest: return "Contact request identifier does not match"
        case .invalidResponse: return "Contact response identifier does not match"
        case .invalidCorrelation: return "Contact message correlation does not match the previous step"
        }
    }
}

public struct ContactWorkflowStateMachine: Equatable, Sendable {
    public private(set) var state: ContactWorkflowState = .idle
    public private(set) var requestID: UUID?
    public private(set) var responseID: UUID?
    public private(set) var capabilityID: String?
    public private(set) var summary: String?

    private var requestMessageID: UUID?
    private var responseMessageID: UUID?
    private var acceptanceMessageID: UUID?

    public init() {}

    public mutating func apply(
        _ message: NearBridgeReliableMessage,
        direction: ContactWorkflowDirection
    ) throws {
        guard let payload = message.payload.contact else { throw ContactWorkflowError.missingPayload }
        guard !payload.capabilityID.isEmpty, payload.capabilityID.count <= 128 else {
            throw ContactWorkflowError.invalidCapability
        }
        guard !payload.summary.isEmpty, payload.summary.count <= 500 else {
            throw ContactWorkflowError.invalidSummary
        }

        switch message.messageType {
        case .contactRequest:
            guard state == .idle else { throw ContactWorkflowError.wrongState }
            guard payload.responseID == nil else { throw ContactWorkflowError.invalidResponse }
            guard message.correlationID == message.messageID else { throw ContactWorkflowError.invalidCorrelation }
            requestID = payload.requestID
            requestMessageID = message.messageID
            capabilityID = payload.capabilityID
            summary = payload.summary
            state = direction == .sent ? .requestSent : .requestReceived

        case .capabilityResponse:
            guard
                (direction == .sent && state == .requestReceived) ||
                (direction == .received && state == .requestSent)
            else { throw ContactWorkflowError.wrongState }
            try validateRequest(payload)
            guard let candidateResponseID = payload.responseID else { throw ContactWorkflowError.invalidResponse }
            guard message.correlationID == requestMessageID else { throw ContactWorkflowError.invalidCorrelation }
            responseID = candidateResponseID
            responseMessageID = message.messageID
            summary = payload.summary
            state = direction == .sent ? .responseSent : .responseReceived

        case .contactAccepted:
            guard
                (direction == .sent && state == .responseReceived) ||
                (direction == .received && state == .responseSent)
            else { throw ContactWorkflowError.wrongState }
            try validateRequest(payload)
            try validateResponse(payload)
            guard message.correlationID == responseMessageID else { throw ContactWorkflowError.invalidCorrelation }
            acceptanceMessageID = message.messageID
            summary = payload.summary
            state = direction == .sent ? .acceptanceSent : .acceptanceReceived

        case .contactCompleted:
            guard
                (direction == .sent && state == .acceptanceReceived) ||
                (direction == .received && state == .acceptanceSent)
            else { throw ContactWorkflowError.wrongState }
            try validateRequest(payload)
            try validateResponse(payload)
            guard message.correlationID == acceptanceMessageID else { throw ContactWorkflowError.invalidCorrelation }
            summary = payload.summary
            state = .completed

        case .ping, .pong, .acknowledgement, .capabilityInvocation, .capabilityResult, .capabilityFailure:
            throw ContactWorkflowError.missingPayload
        }
    }

    public mutating func reset() {
        self = ContactWorkflowStateMachine()
    }

    public var requestCorrelationID: UUID? { requestMessageID }
    public var responseCorrelationID: UUID? { responseMessageID }
    public var acceptanceCorrelationID: UUID? { acceptanceMessageID }

    private func validateRequest(_ payload: ContactWorkflowPayload) throws {
        guard payload.requestID == requestID, payload.capabilityID == capabilityID else {
            throw ContactWorkflowError.invalidRequest
        }
    }

    private func validateResponse(_ payload: ContactWorkflowPayload) throws {
        guard payload.responseID == responseID else { throw ContactWorkflowError.invalidResponse }
    }
}
