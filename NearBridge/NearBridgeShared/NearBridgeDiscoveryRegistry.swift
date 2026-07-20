import Foundation

public struct NearBridgeDiscoveryRegistry: Sendable {
    private var entries: [String: NearBridgePeer] = [:]

    public init() {}

    public var peers: [NearBridgePeer] {
        entries.values.sorted {
            if $0.displayName == $1.displayName { return $0.id < $1.id }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    @discardableResult
    public mutating func reconcile(
        _ observations: [ExperimentPeer],
        at now: Date = Date()
    ) -> [NearBridgeDiscoveryChange] {
        var changes: [NearBridgeDiscoveryChange] = []
        let unique = Dictionary(observations.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        let visibleIDs = Set(unique.keys)

        let lostIDs = entries.keys.filter { !visibleIDs.contains($0) }
        for identifier in lostIDs {
            if let removed = entries.removeValue(forKey: identifier) {
                changes.append(.lost(removed))
            }
        }

        for (identifier, observation) in unique {
            if let existing = entries[identifier] {
                entries[identifier] = NearBridgePeer(
                    id: existing.id,
                    displayName: observation.displayName,
                    roleHint: Self.roleHint(for: observation.displayName),
                    discoveryReference: observation.endpointDescription,
                    firstSeenAt: existing.firstSeenAt,
                    lastSeenAt: now,
                    trustState: .untrusted
                )
            } else {
                let peer = NearBridgePeer(
                    id: identifier,
                    displayName: observation.displayName,
                    roleHint: Self.roleHint(for: observation.displayName),
                    discoveryReference: observation.endpointDescription,
                    firstSeenAt: now,
                    lastSeenAt: now,
                    trustState: .untrusted
                )
                entries[identifier] = peer
                changes.append(.found(peer))
            }
        }

        return changes.sorted { Self.changeKey($0) < Self.changeKey($1) }
    }

    @discardableResult
    public mutating func removeAll() -> [NearBridgeDiscoveryChange] {
        let changes = peers.map(NearBridgeDiscoveryChange.lost)
        entries.removeAll()
        return changes
    }

    private static func roleHint(for displayName: String) -> DeviceRole? {
        let normalized = displayName.lowercased()
        if normalized.contains("iphone") { return .iPhone }
        if normalized.contains("mac") { return .mac }
        return nil
    }

    private static func changeKey(_ change: NearBridgeDiscoveryChange) -> String {
        switch change {
        case .found(let peer): return "0-\(peer.id)"
        case .lost(let peer): return "1-\(peer.id)"
        }
    }
}
