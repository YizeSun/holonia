import Foundation

public enum NearBridgePhase: Int, Codable, CaseIterable, Comparable, Sendable {
    case nb1 = 1
    case nb2 = 2
    case nb3 = 3
    case nb4 = 4
    case nb5 = 5
    case nb6 = 6
    case nb7 = 7
    case nb8 = 8
    case nb9 = 9

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var displayName: String { "NB-\(rawValue)" }

    public var allowsTransportSessions: Bool {
        self >= .nb2
    }
}

public enum NearBridgeBuild {
    public static let phase = NearBridgePhase.nb9
    public static let automatedStatus = "Automated checkpoint"
    public static let physicalStatus = "Physical validation pending"
}

public enum PeerTrustState: String, Codable, Sendable {
    case untrusted
    case paired
}

public enum LocalNetworkAccessState: String, Codable, Sendable {
    case unknown
    case available
    case attentionRequired
}

public struct NearBridgePeer: Identifiable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let roleHint: DeviceRole?
    public let discoveryReference: String
    public let firstSeenAt: Date
    public let lastSeenAt: Date
    public let trustState: PeerTrustState

    public init(
        id: String,
        displayName: String,
        roleHint: DeviceRole?,
        discoveryReference: String,
        firstSeenAt: Date,
        lastSeenAt: Date,
        trustState: PeerTrustState = .untrusted
    ) {
        self.id = id
        self.displayName = displayName
        self.roleHint = roleHint
        self.discoveryReference = discoveryReference
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.trustState = trustState
    }
}

public enum NearBridgeDiscoveryChange: Equatable, Sendable {
    case found(NearBridgePeer)
    case lost(NearBridgePeer)
}

public enum NearBridgeEventCategory: String, Codable, Sendable {
    case applicationLifecycle
    case localNetworkPermission
    case discovery
    case peerFound
    case peerLost
    case identity
    case pairing
    case revocation
    case connection
    case authentication
    case messageSend
    case messageReceive
    case timeout
    case workflow
    case capability
    case frameworkError
}

public enum AuthenticatedSessionState: String, Codable, Sendable {
    case idle
    case pairing
    case authenticated
    case failed
}

public struct PendingPairing: Identifiable, Equatable, Sendable {
    public let nodeID: String
    public let displayName: String
    public let role: DeviceRole
    public let fingerprint: String
    public let verificationCode: String
    public let state: PairingApprovalState
    public let isKnownPairing: Bool

    public var id: String { nodeID }
}

public struct NearBridgeEvent: Codable, Identifiable, Equatable, Sendable {
    public let eventID: UUID
    public let timestamp: Date
    public let phase: NearBridgePhase
    public let deviceRole: DeviceRole
    public let category: NearBridgeEventCategory
    public let state: String
    public let peerReference: String?
    public let messageReference: UUID?
    public let errorDomain: String?
    public let errorCode: Int?
    public let humanReadableDetail: String

    public var id: UUID { eventID }

    public init(
        eventID: UUID = UUID(),
        timestamp: Date = Date(),
        phase: NearBridgePhase,
        deviceRole: DeviceRole,
        category: NearBridgeEventCategory,
        state: String,
        peerReference: String? = nil,
        messageReference: UUID? = nil,
        error: Error? = nil,
        humanReadableDetail: String
    ) {
        let nsError = error as NSError?
        self.eventID = eventID
        self.timestamp = timestamp
        self.phase = phase
        self.deviceRole = deviceRole
        self.category = category
        self.state = state
        self.peerReference = peerReference
        self.messageReference = messageReference
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
        let messageSuffix = messageReference.map { " [message \($0.uuidString)]" } ?? ""
        return "\(time) [\(phase.displayName)] \(category.rawValue).\(state): \(humanReadableDetail)\(messageSuffix)\(errorSuffix)"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}
