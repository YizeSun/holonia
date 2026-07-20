import CryptoKit
import Foundation

public enum PairingMessageKind: String, Codable, Sendable {
    case hello
    case confirmation
}

public struct PairingHello: Codable, Equatable, Sendable {
    public let nodeID: String
    public let publicKeyBase64: String
    public let displayName: String
    public let role: DeviceRole
    public let nonceBase64: String
    public let signatureBase64: String
}

public struct PairingConfirmation: Codable, Equatable, Sendable {
    public let nodeID: String
    public let transcriptHashBase64: String
    public let signatureBase64: String
}

public struct PairingEnvelope: Codable, Equatable, Identifiable, Sendable {
    public static let supportedSchemaVersion = 1

    public let schemaVersion: Int
    public let messageID: UUID
    public let kind: PairingMessageKind
    public let hello: PairingHello?
    public let confirmation: PairingConfirmation?

    public var id: UUID { messageID }

    public init(
        schemaVersion: Int = supportedSchemaVersion,
        messageID: UUID = UUID(),
        kind: PairingMessageKind,
        hello: PairingHello? = nil,
        confirmation: PairingConfirmation? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.messageID = messageID
        self.kind = kind
        self.hello = hello
        self.confirmation = confirmation
    }
}

public enum PairingProtocolError: Error, Equatable, LocalizedError {
    case malformedMessage
    case unsupportedSchema(Int)
    case invalidPayload
    case invalidBase64
    case identityMismatch
    case invalidSignature
    case transcriptMismatch

    public var errorDescription: String? {
        switch self {
        case .malformedMessage: return "Malformed pairing message"
        case .unsupportedSchema(let version): return "Unsupported pairing schema \(version)"
        case .invalidPayload: return "Pairing message contains an invalid payload"
        case .invalidBase64: return "Pairing message contains invalid base64 data"
        case .identityMismatch: return "Pairing public key does not match the claimed node identity"
        case .invalidSignature: return "Pairing proof signature is invalid"
        case .transcriptMismatch: return "Pairing confirmation does not match this session"
        }
    }
}

public enum PairingProtocol {
    private struct UnsignedHello: Codable {
        let nodeID: String
        let publicKeyBase64: String
        let displayName: String
        let role: DeviceRole
        let nonceBase64: String
    }

    public static func makeHello(
        identityManager: HostIdentityManager,
        role: DeviceRole,
        displayName: String,
        nonce: Data
    ) throws -> PairingHello {
        let unsigned = UnsignedHello(
            nodeID: identityManager.identity.nodeID,
            publicKeyBase64: identityManager.identity.publicKeyBase64,
            displayName: String(displayName.prefix(64)),
            role: role,
            nonceBase64: nonce.base64EncodedString()
        )
        let signedData = try canonicalData(unsigned)
        return PairingHello(
            nodeID: unsigned.nodeID,
            publicKeyBase64: unsigned.publicKeyBase64,
            displayName: unsigned.displayName,
            role: unsigned.role,
            nonceBase64: unsigned.nonceBase64,
            signatureBase64: try identityManager.sign(signedData).base64EncodedString()
        )
    }

    public static func verify(_ hello: PairingHello) throws {
        guard
            let publicKey = Data(base64Encoded: hello.publicKeyBase64),
            Data(base64Encoded: hello.nonceBase64) != nil,
            let signature = Data(base64Encoded: hello.signatureBase64)
        else { throw PairingProtocolError.invalidBase64 }
        guard HostIdentityManager.nodeID(for: publicKey) == hello.nodeID else {
            throw PairingProtocolError.identityMismatch
        }
        let unsigned = UnsignedHello(
            nodeID: hello.nodeID,
            publicKeyBase64: hello.publicKeyBase64,
            displayName: hello.displayName,
            role: hello.role,
            nonceBase64: hello.nonceBase64
        )
        guard HostIdentityManager.verify(signature: signature, data: try canonicalData(unsigned), publicKey: publicKey) else {
            throw PairingProtocolError.invalidSignature
        }
    }

    public static func transcriptHash(local: PairingHello, remote: PairingHello) throws -> Data {
        try verify(local)
        try verify(remote)
        guard local.nodeID != remote.nodeID else { throw PairingProtocolError.identityMismatch }
        let ordered = [local, remote].sorted { $0.nodeID < $1.nodeID }
        let bytes = try canonicalData(ordered)
        return Data(SHA256.hash(data: bytes))
    }

    public static func pairingCode(transcriptHash: Data) -> String {
        let prefix = transcriptHash.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        return String(format: "%06d", prefix % 1_000_000)
    }

    public static func makeConfirmation(
        identityManager: HostIdentityManager,
        transcriptHash: Data
    ) throws -> PairingConfirmation {
        let hash = transcriptHash.base64EncodedString()
        let signedData = confirmationData(nodeID: identityManager.identity.nodeID, transcriptHashBase64: hash)
        return PairingConfirmation(
            nodeID: identityManager.identity.nodeID,
            transcriptHashBase64: hash,
            signatureBase64: try identityManager.sign(signedData).base64EncodedString()
        )
    }

    public static func verify(
        _ confirmation: PairingConfirmation,
        expectedTranscriptHash: Data,
        peerHello: PairingHello
    ) throws {
        guard confirmation.nodeID == peerHello.nodeID else { throw PairingProtocolError.identityMismatch }
        let expected = expectedTranscriptHash.base64EncodedString()
        guard confirmation.transcriptHashBase64 == expected else { throw PairingProtocolError.transcriptMismatch }
        guard
            let signature = Data(base64Encoded: confirmation.signatureBase64),
            let publicKey = Data(base64Encoded: peerHello.publicKeyBase64)
        else { throw PairingProtocolError.invalidBase64 }
        let signedData = confirmationData(nodeID: confirmation.nodeID, transcriptHashBase64: expected)
        guard HostIdentityManager.verify(signature: signature, data: signedData, publicKey: publicKey) else {
            throw PairingProtocolError.invalidSignature
        }
    }

    public static func encode(_ envelope: PairingEnvelope) throws -> Data {
        try validate(envelope)
        return try canonicalData(envelope)
    }

    public static func decode(_ data: Data) throws -> PairingEnvelope {
        guard let envelope = try? JSONDecoder().decode(PairingEnvelope.self, from: data) else {
            throw PairingProtocolError.malformedMessage
        }
        try validate(envelope)
        return envelope
    }

    private static func validate(_ envelope: PairingEnvelope) throws {
        guard envelope.schemaVersion == PairingEnvelope.supportedSchemaVersion else {
            throw PairingProtocolError.unsupportedSchema(envelope.schemaVersion)
        }
        switch envelope.kind {
        case .hello:
            guard let hello = envelope.hello, envelope.confirmation == nil else { throw PairingProtocolError.invalidPayload }
            try verify(hello)
        case .confirmation:
            guard envelope.hello == nil, envelope.confirmation != nil else { throw PairingProtocolError.invalidPayload }
        }
    }

    private static func confirmationData(nodeID: String, transcriptHashBase64: String) -> Data {
        Data("nearbridge-pair-confirm-v1|\(nodeID)|\(transcriptHashBase64)".utf8)
    }

    private static func canonicalData<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
}

public enum PairingApprovalState: String, Codable, Equatable, Sendable {
    case idle
    case awaitingLocalApproval
    case awaitingRemoteConfirmation
    case established
    case rejected
}

public struct NearBridgePairingStateMachine: Equatable, Sendable {
    public private(set) var state: PairingApprovalState = .idle
    public private(set) var hasVerifiedHello = false
    public private(set) var localApproved = false
    public private(set) var remoteConfirmed = false

    public init() {}

    public mutating func receiveVerifiedHello() {
        guard state != .rejected && state != .established else { return }
        hasVerifiedHello = true
        state = localApproved ? .awaitingRemoteConfirmation : .awaitingLocalApproval
        settleIfComplete()
    }

    public mutating func approveLocally() {
        guard hasVerifiedHello, state != .rejected else { return }
        localApproved = true
        state = remoteConfirmed ? .established : .awaitingRemoteConfirmation
    }

    public mutating func receiveVerifiedConfirmation() {
        guard hasVerifiedHello, state != .rejected else { return }
        remoteConfirmed = true
        settleIfComplete()
    }

    public mutating func reject() {
        state = .rejected
    }

    private mutating func settleIfComplete() {
        if localApproved && remoteConfirmed {
            state = .established
        } else if hasVerifiedHello && !localApproved {
            state = .awaitingLocalApproval
        }
    }
}
