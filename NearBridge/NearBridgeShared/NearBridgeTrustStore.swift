import Foundation

public struct PairedNodeRecord: Codable, Equatable, Identifiable, Sendable {
    public let nodeID: String
    public let displayName: String
    public let role: DeviceRole
    public let publicKeyBase64: String
    public let pairedAt: Date

    public var id: String { nodeID }
    public var fingerprint: String { String(nodeID.prefix(12)).uppercased() }

    public init(
        nodeID: String,
        displayName: String,
        role: DeviceRole,
        publicKeyBase64: String,
        pairedAt: Date = Date()
    ) {
        self.nodeID = nodeID
        self.displayName = displayName
        self.role = role
        self.publicKeyBase64 = publicKeyBase64
        self.pairedAt = pairedAt
    }
}

public struct NearBridgeTrustRegistry: Equatable, Sendable {
    private var recordsByID: [String: PairedNodeRecord]

    public init(records: [PairedNodeRecord] = []) {
        recordsByID = Dictionary(records.map { ($0.nodeID, $0) }, uniquingKeysWith: { _, latest in latest })
    }

    public var records: [PairedNodeRecord] {
        recordsByID.values.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    public func contains(nodeID: String) -> Bool {
        recordsByID[nodeID] != nil
    }

    public mutating func trust(_ record: PairedNodeRecord) {
        recordsByID[record.nodeID] = record
    }

    @discardableResult
    public mutating func revoke(nodeID: String) -> PairedNodeRecord? {
        recordsByID.removeValue(forKey: nodeID)
    }
}

final class KeychainPairingRecordStore {
    private let blobs = KeychainBlobStore(service: "org.holonia.nearbridge.host")
    private let account = "paired-nodes-v1"

    func load() throws -> NearBridgeTrustRegistry {
        guard let data = try blobs.read(account: account) else { return NearBridgeTrustRegistry() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return NearBridgeTrustRegistry(records: try decoder.decode([PairedNodeRecord].self, from: data))
    }

    func save(_ registry: NearBridgeTrustRegistry) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        try blobs.write(encoder.encode(registry.records), account: account)
    }
}
