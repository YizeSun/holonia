import Foundation

public enum ExperimentEventCategory: String, Codable, Sendable {
    case applicationLifecycle
    case localNetworkPermission
    case advertisement
    case browsing
    case peerDiscovered
    case peerLost
    case invitation
    case connection
    case disconnection
    case reconnection
    case messageSend
    case messageReceive
    case timeout
    case frameworkError
    case decodingError
}

public struct ExperimentEvent: Codable, Identifiable, Equatable, Sendable {
    public let eventID: UUID
    public let timestamp: Date
    public let deviceRole: DeviceRole
    public let experiment: ExperimentKind
    public let category: ExperimentEventCategory
    public let state: String
    public let peerReference: String?
    public let messageReference: UUID?
    public let durationMilliseconds: Double?
    public let errorDomain: String?
    public let errorCode: Int?
    public let humanReadableDetail: String

    public var id: UUID { eventID }

    public init(
        eventID: UUID = UUID(),
        timestamp: Date = Date(),
        deviceRole: DeviceRole,
        experiment: ExperimentKind,
        category: ExperimentEventCategory,
        state: String,
        peerReference: String? = nil,
        messageReference: UUID? = nil,
        durationMilliseconds: Double? = nil,
        error: Error? = nil,
        humanReadableDetail: String
    ) {
        let nsError = error as NSError?
        self.eventID = eventID
        self.timestamp = timestamp
        self.deviceRole = deviceRole
        self.experiment = experiment
        self.category = category
        self.state = state
        self.peerReference = peerReference
        self.messageReference = messageReference
        self.durationMilliseconds = durationMilliseconds
        self.errorDomain = nsError?.domain
        self.errorCode = nsError?.code
        self.humanReadableDetail = humanReadableDetail
    }

    public var compactDescription: String {
        let time = Self.timeFormatter.string(from: timestamp)
        let errorSuffix: String
        if let errorDomain, let errorCode {
            errorSuffix = " [error \(errorDomain):\(errorCode)]"
        } else {
            errorSuffix = ""
        }
        return "\(time) [\(experiment.rawValue)] \(category.rawValue).\(state): \(humanReadableDetail)\(errorSuffix)"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}
