import Foundation

public enum ReliableMessageType: String, Codable, Sendable {
    case ping
    case pong
    case acknowledgement
}

public struct ReliableMessagePayload: Codable, Equatable, Sendable {
    public let sequence: Int

    public init(sequence: Int) {
        self.sequence = sequence
    }
}

public struct NearBridgeReliableMessage: Codable, Equatable, Identifiable, Sendable {
    public static let protocolName = "nearbridge.message.v1"
    public static let supportedSchemaVersion = 1

    public let protocolName: String
    public let schemaVersion: Int
    public let messageID: UUID
    public let senderNodeID: String
    public let sessionID: String
    public let messageType: ReliableMessageType
    public let sentAtMilliseconds: Int64
    public let expiresAtMilliseconds: Int64
    public let correlationID: UUID
    public let payload: ReliableMessagePayload
    public let signatureBase64: String

    public var id: UUID { messageID }

    public init(
        protocolName: String = NearBridgeReliableMessage.protocolName,
        schemaVersion: Int = supportedSchemaVersion,
        messageID: UUID,
        senderNodeID: String,
        sessionID: String,
        messageType: ReliableMessageType,
        sentAtMilliseconds: Int64,
        expiresAtMilliseconds: Int64,
        correlationID: UUID,
        payload: ReliableMessagePayload,
        signatureBase64: String
    ) {
        self.protocolName = protocolName
        self.schemaVersion = schemaVersion
        self.messageID = messageID
        self.senderNodeID = senderNodeID
        self.sessionID = sessionID
        self.messageType = messageType
        self.sentAtMilliseconds = sentAtMilliseconds
        self.expiresAtMilliseconds = expiresAtMilliseconds
        self.correlationID = correlationID
        self.payload = payload
        self.signatureBase64 = signatureBase64
    }
}

public enum ReliableMessageError: Error, Equatable, LocalizedError {
    case malformedMessage
    case unsupportedProtocol
    case unsupportedSchema(Int)
    case invalidCorrelation
    case invalidLifetime
    case expired
    case sentTooFarInFuture
    case unexpectedSender
    case wrongSession
    case invalidPublicKey
    case invalidSignature
    case replayWindowExhausted

    public var errorDescription: String? {
        switch self {
        case .malformedMessage: return "Malformed reliable message"
        case .unsupportedProtocol: return "Unsupported NearBridge wire protocol"
        case .unsupportedSchema(let version): return "Unsupported reliable-message schema \(version)"
        case .invalidCorrelation: return "Message correlation is invalid"
        case .invalidLifetime: return "Message lifetime is invalid"
        case .expired: return "Message has expired"
        case .sentTooFarInFuture: return "Message timestamp is too far in the future"
        case .unexpectedSender: return "Message sender is not the paired session peer"
        case .wrongSession: return "Message belongs to a different session"
        case .invalidPublicKey: return "Paired public key is invalid"
        case .invalidSignature: return "Message integrity signature is invalid"
        case .replayWindowExhausted: return "Session replay window is exhausted"
        }
    }
}

public enum ReliableMessageAcceptance: Equatable, Sendable {
    case accepted(NearBridgeReliableMessage)
    case duplicateIgnored(UUID)
}

public enum ReliableMessageCodec {
    private struct UnsignedMessage: Codable {
        let protocolName: String
        let schemaVersion: Int
        let messageID: UUID
        let senderNodeID: String
        let sessionID: String
        let messageType: ReliableMessageType
        let sentAtMilliseconds: Int64
        let expiresAtMilliseconds: Int64
        let correlationID: UUID
        let payload: ReliableMessagePayload
    }

    public static func makePing(
        sequence: Int,
        sessionID: String,
        identityManager: HostIdentityManager,
        nowMilliseconds: Int64 = currentMilliseconds(),
        lifetimeMilliseconds: Int64 = 30_000,
        messageID: UUID = UUID()
    ) throws -> NearBridgeReliableMessage {
        try sign(
            messageID: messageID,
            senderNodeID: identityManager.identity.nodeID,
            sessionID: sessionID,
            messageType: .ping,
            sentAtMilliseconds: nowMilliseconds,
            expiresAtMilliseconds: nowMilliseconds + lifetimeMilliseconds,
            correlationID: messageID,
            payload: .init(sequence: sequence),
            identityManager: identityManager
        )
    }

    public static func makePong(
        for ping: NearBridgeReliableMessage,
        sessionID: String,
        identityManager: HostIdentityManager,
        nowMilliseconds: Int64 = currentMilliseconds(),
        lifetimeMilliseconds: Int64 = 30_000,
        messageID: UUID = UUID()
    ) throws -> NearBridgeReliableMessage {
        try sign(
            messageID: messageID,
            senderNodeID: identityManager.identity.nodeID,
            sessionID: sessionID,
            messageType: .pong,
            sentAtMilliseconds: nowMilliseconds,
            expiresAtMilliseconds: nowMilliseconds + lifetimeMilliseconds,
            correlationID: ping.correlationID,
            payload: ping.payload,
            identityManager: identityManager
        )
    }

    public static func makeAcknowledgement(
        for message: NearBridgeReliableMessage,
        sessionID: String,
        identityManager: HostIdentityManager,
        nowMilliseconds: Int64 = currentMilliseconds(),
        lifetimeMilliseconds: Int64 = 30_000,
        messageID: UUID = UUID()
    ) throws -> NearBridgeReliableMessage {
        try sign(
            messageID: messageID,
            senderNodeID: identityManager.identity.nodeID,
            sessionID: sessionID,
            messageType: .acknowledgement,
            sentAtMilliseconds: nowMilliseconds,
            expiresAtMilliseconds: nowMilliseconds + lifetimeMilliseconds,
            correlationID: message.messageID,
            payload: message.payload,
            identityManager: identityManager
        )
    }

    public static func encode(_ message: NearBridgeReliableMessage) throws -> Data {
        try validateStructure(message)
        return try canonicalData(message)
    }

    public static func decode(_ data: Data) throws -> NearBridgeReliableMessage {
        guard let message = try? JSONDecoder().decode(NearBridgeReliableMessage.self, from: data) else {
            throw ReliableMessageError.malformedMessage
        }
        try validateStructure(message)
        return message
    }

    public static func verifySignature(
        _ message: NearBridgeReliableMessage,
        publicKeyBase64: String
    ) throws {
        guard
            let publicKey = Data(base64Encoded: publicKeyBase64),
            let signature = Data(base64Encoded: message.signatureBase64)
        else { throw ReliableMessageError.invalidPublicKey }
        guard HostIdentityManager.verify(
            signature: signature,
            data: try canonicalData(unsigned(message)),
            publicKey: publicKey
        ) else { throw ReliableMessageError.invalidSignature }
    }

    public static func currentMilliseconds(_ date: Date = Date()) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1_000).rounded(.down))
    }

    private static func sign(
        messageID: UUID,
        senderNodeID: String,
        sessionID: String,
        messageType: ReliableMessageType,
        sentAtMilliseconds: Int64,
        expiresAtMilliseconds: Int64,
        correlationID: UUID,
        payload: ReliableMessagePayload,
        identityManager: HostIdentityManager
    ) throws -> NearBridgeReliableMessage {
        let unsigned = UnsignedMessage(
            protocolName: NearBridgeReliableMessage.protocolName,
            schemaVersion: NearBridgeReliableMessage.supportedSchemaVersion,
            messageID: messageID,
            senderNodeID: senderNodeID,
            sessionID: sessionID,
            messageType: messageType,
            sentAtMilliseconds: sentAtMilliseconds,
            expiresAtMilliseconds: expiresAtMilliseconds,
            correlationID: correlationID,
            payload: payload
        )
        return NearBridgeReliableMessage(
            protocolName: unsigned.protocolName,
            schemaVersion: unsigned.schemaVersion,
            messageID: unsigned.messageID,
            senderNodeID: unsigned.senderNodeID,
            sessionID: unsigned.sessionID,
            messageType: unsigned.messageType,
            sentAtMilliseconds: unsigned.sentAtMilliseconds,
            expiresAtMilliseconds: unsigned.expiresAtMilliseconds,
            correlationID: unsigned.correlationID,
            payload: unsigned.payload,
            signatureBase64: try identityManager.sign(canonicalData(unsigned)).base64EncodedString()
        )
    }

    private static func validateStructure(_ message: NearBridgeReliableMessage) throws {
        guard message.protocolName == NearBridgeReliableMessage.protocolName else { throw ReliableMessageError.unsupportedProtocol }
        guard message.schemaVersion == NearBridgeReliableMessage.supportedSchemaVersion else {
            throw ReliableMessageError.unsupportedSchema(message.schemaVersion)
        }
        guard message.expiresAtMilliseconds > message.sentAtMilliseconds,
              message.expiresAtMilliseconds - message.sentAtMilliseconds <= 60_000 else {
            throw ReliableMessageError.invalidLifetime
        }
        if message.messageType == .ping && message.correlationID != message.messageID {
            throw ReliableMessageError.invalidCorrelation
        }
    }

    private static func unsigned(_ message: NearBridgeReliableMessage) -> UnsignedMessage {
        UnsignedMessage(
            protocolName: message.protocolName,
            schemaVersion: message.schemaVersion,
            messageID: message.messageID,
            senderNodeID: message.senderNodeID,
            sessionID: message.sessionID,
            messageType: message.messageType,
            sentAtMilliseconds: message.sentAtMilliseconds,
            expiresAtMilliseconds: message.expiresAtMilliseconds,
            correlationID: message.correlationID,
            payload: message.payload
        )
    }

    private static func canonicalData<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
}

public struct ReliableMessageValidator: Sendable {
    private let expectedSenderNodeID: String
    private let expectedSessionID: String
    private let publicKeyBase64: String
    private var receivedMessageIDs: Set<UUID> = []

    public init(expectedSenderNodeID: String, expectedSessionID: String, publicKeyBase64: String) {
        self.expectedSenderNodeID = expectedSenderNodeID
        self.expectedSessionID = expectedSessionID
        self.publicKeyBase64 = publicKeyBase64
    }

    public mutating func validate(
        _ message: NearBridgeReliableMessage,
        nowMilliseconds: Int64 = ReliableMessageCodec.currentMilliseconds()
    ) throws -> ReliableMessageAcceptance {
        guard message.senderNodeID == expectedSenderNodeID else { throw ReliableMessageError.unexpectedSender }
        guard message.sessionID == expectedSessionID else { throw ReliableMessageError.wrongSession }
        guard message.sentAtMilliseconds <= nowMilliseconds + 5_000 else { throw ReliableMessageError.sentTooFarInFuture }
        guard message.expiresAtMilliseconds > nowMilliseconds else { throw ReliableMessageError.expired }
        try ReliableMessageCodec.verifySignature(message, publicKeyBase64: publicKeyBase64)
        if receivedMessageIDs.contains(message.messageID) {
            return .duplicateIgnored(message.messageID)
        }
        guard receivedMessageIDs.count < 4_096 else { throw ReliableMessageError.replayWindowExhausted }
        receivedMessageIDs.insert(message.messageID)
        return .accepted(message)
    }
}

enum NearBridgeWireProtocol {
    static func name(in data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let protocolName = object["protocolName"] as? String
        else { return nil }
        return protocolName
    }
}
