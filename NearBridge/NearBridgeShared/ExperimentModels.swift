import Foundation

public enum ExperimentKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case bonjourNetwork = "Bonjour + Network.framework"
    case multipeerConnectivity = "MultipeerConnectivity"
    case udpMulticastProbe = "UDP multicast probe"

    public var id: String { rawValue }
    public var supportsSessions: Bool { self != .udpMulticastProbe }
}

public enum DeviceRole: String, Codable, Equatable, Sendable {
    case iPhone
    case mac
}

public enum DiscoveryState: String, Codable, Sendable {
    case stopped, starting, advertising, browsing, peerDiscovered, peerLost, failed
}

public enum SessionState: String, Codable, Sendable {
    case idle, connecting, connected, disconnecting, disconnected, reconnecting, failed
}

public enum MessageState: String, Codable, Sendable {
    case created, sending, sent, received, responded, timedOut, failed
}

public enum ExperimentMessageType: String, Codable, Sendable {
    case ping, pong
}

public struct ExperimentPayload: Codable, Equatable, Sendable {
    public let sequence: Int

    public init(sequence: Int) {
        self.sequence = sequence
    }
}

public struct ExperimentMessage: Codable, Equatable, Identifiable, Sendable {
    public static let supportedSchemaVersion = 1

    public let schemaVersion: Int
    public let messageID: UUID
    public let messageType: ExperimentMessageType
    public let sentAt: Date
    public let correlationID: UUID
    public let payload: ExperimentPayload

    public var id: UUID { messageID }

    public init(
        schemaVersion: Int = supportedSchemaVersion,
        messageID: UUID = UUID(),
        messageType: ExperimentMessageType,
        sentAt: Date = Date(),
        correlationID: UUID,
        payload: ExperimentPayload
    ) {
        self.schemaVersion = schemaVersion
        self.messageID = messageID
        self.messageType = messageType
        self.sentAt = sentAt
        self.correlationID = correlationID
        self.payload = payload
    }

    public static func ping(sequence: Int, now: Date = Date(), id: UUID = UUID()) -> Self {
        Self(
            messageID: id,
            messageType: .ping,
            sentAt: now,
            correlationID: id,
            payload: .init(sequence: sequence)
        )
    }

    public static func pong(for ping: Self, now: Date = Date(), id: UUID = UUID()) -> Self {
        Self(
            messageID: id,
            messageType: .pong,
            sentAt: now,
            correlationID: ping.correlationID,
            payload: ping.payload
        )
    }

    public func validate() throws {
        guard schemaVersion == Self.supportedSchemaVersion else {
            throw ExperimentMessageError.unsupportedSchemaVersion(schemaVersion)
        }
        if messageType == .ping && correlationID != messageID {
            throw ExperimentMessageError.invalidPingCorrelation
        }
    }
}

public enum ExperimentMessageError: Error, Equatable, LocalizedError {
    case unsupportedSchemaVersion(Int)
    case invalidPingCorrelation
    case malformedMessage

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version):
            return "Unsupported experimental schema version \(version)"
        case .invalidPingCorrelation:
            return "A ping must correlate to its own message identifier"
        case .malformedMessage:
            return "Malformed experimental message"
        }
    }
}

public enum ExperimentMessageCodec {
    public static func encode(_ message: ExperimentMessage) throws -> Data {
        try message.validate()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(message)
    }

    public static func decode(_ data: Data) throws -> ExperimentMessage {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let message = try? decoder.decode(ExperimentMessage.self, from: data) else {
            throw ExperimentMessageError.malformedMessage
        }
        try message.validate()
        return message
    }
}

public struct ExperimentPeer: Identifiable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let endpointDescription: String

    public init(id: String, displayName: String, endpointDescription: String) {
        self.id = id
        self.displayName = displayName
        self.endpointDescription = endpointDescription
    }
}

public struct MessageIdentifierTracker: Sendable {
    private var identifiers: Set<UUID> = []

    public init() {}

    public mutating func insert(_ identifier: UUID) -> Bool {
        identifiers.insert(identifier).inserted
    }
}
