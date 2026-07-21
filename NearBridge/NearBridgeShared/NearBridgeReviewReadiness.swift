import CryptoKit
import Foundation

public enum NearBridgePresentationMode: String, CaseIterable, Identifiable, Sendable {
    case demo = "Demo"
    case diagnostics = "Diagnostics"

    public var id: String { rawValue }
}

public enum NearBridgeReadinessState: String, Codable, Equatable, Sendable {
    case ready
    case waiting
    case actionRequired
}

public struct NearBridgeReadinessItem: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let state: NearBridgeReadinessState

    public init(id: String, title: String, detail: String, state: NearBridgeReadinessState) {
        self.id = id
        self.title = title
        self.detail = detail
        self.state = state
    }
}

public struct NearBridgeReadinessContext: Equatable, Sendable {
    public let isRunning: Bool
    public let localNetworkAccess: LocalNetworkAccessState
    public let peerCount: Int
    public let sessionState: SessionState
    public let authenticationState: AuthenticatedSessionState
    public let contactState: ContactWorkflowState
    public let capabilityState: CapabilityExecutionState
    public let primaryHolonSelected: Bool
    public let primaryHolonNeedsCredential: Bool
    public let primaryHolonCredentialConfigured: Bool

    public init(
        isRunning: Bool,
        localNetworkAccess: LocalNetworkAccessState,
        peerCount: Int,
        sessionState: SessionState,
        authenticationState: AuthenticatedSessionState,
        contactState: ContactWorkflowState,
        capabilityState: CapabilityExecutionState,
        primaryHolonSelected: Bool,
        primaryHolonNeedsCredential: Bool,
        primaryHolonCredentialConfigured: Bool
    ) {
        self.isRunning = isRunning
        self.localNetworkAccess = localNetworkAccess
        self.peerCount = peerCount
        self.sessionState = sessionState
        self.authenticationState = authenticationState
        self.contactState = contactState
        self.capabilityState = capabilityState
        self.primaryHolonSelected = primaryHolonSelected
        self.primaryHolonNeedsCredential = primaryHolonNeedsCredential
        self.primaryHolonCredentialConfigured = primaryHolonCredentialConfigured
    }
}

public enum NearBridgeReviewReadiness {
    public static func items(for context: NearBridgeReadinessContext) -> [NearBridgeReadinessItem] {
        let discovery: NearBridgeReadinessItem
        if context.localNetworkAccess == .attentionRequired {
            discovery = .init(
                id: "discovery",
                title: "Local discovery",
                detail: "Enable Local Network access, then restart discovery.",
                state: .actionRequired
            )
        } else if context.isRunning {
            let peerIsAvailable = context.peerCount > 0 || context.sessionState == .connected || context.authenticationState == .authenticated
            discovery = .init(
                id: "discovery",
                title: "Local discovery",
                detail: peerIsAvailable ? "A nearby node is visible or connected." : "Advertising and browsing on the local network.",
                state: peerIsAvailable ? .ready : .waiting
            )
        } else {
            discovery = .init(id: "discovery", title: "Local discovery", detail: "Start discovery.", state: .actionRequired)
        }

        let authenticated = context.authenticationState == .authenticated
        let session = NearBridgeReadinessItem(
            id: "session",
            title: "Authenticated session",
            detail: authenticated ? "The fresh session is bound to approved Host keys." : "Pair one visible node and approve the same code on both devices.",
            state: authenticated ? .ready : (context.sessionState == .connecting ? .waiting : .actionRequired)
        )

        let contactCompleted = context.contactState == .completed
        let contact = NearBridgeReadinessItem(
            id: "contact",
            title: "Primary Holon contact",
            detail: contactCompleted ? "The signed capability contract is accepted." : "Complete Request → Response → Accept → Complete.",
            state: contactCompleted ? .ready : (authenticated ? .actionRequired : .waiting)
        )

        let implementation: NearBridgeReadinessItem
        if !context.primaryHolonSelected {
            implementation = .init(id: "implementation", title: "Primary Holon", detail: "Select a Host implementation.", state: .actionRequired)
        } else if context.primaryHolonNeedsCredential && !context.primaryHolonCredentialConfigured {
            implementation = .init(id: "implementation", title: "Primary Holon", detail: "Save an OpenAI API key in the Mac Host Keychain, or select an on-device implementation.", state: .actionRequired)
        } else {
            implementation = .init(id: "implementation", title: "Primary Holon", detail: "A bounded Host adapter is ready.", state: .ready)
        }

        let execution: NearBridgeReadinessItem
        switch context.capabilityState {
        case .succeeded:
            execution = .init(id: "execution", title: "Signed answer", detail: "A correlated result completed successfully.", state: .ready)
        case .failed:
            execution = .init(id: "execution", title: "Signed answer", detail: "Review the error, correct it, and retry the same question.", state: .actionRequired)
        case .requestSent, .executing:
            execution = .init(id: "execution", title: "Signed answer", detail: "The bounded request is in progress.", state: .waiting)
        case .idle:
            execution = .init(id: "execution", title: "Signed answer", detail: "Ask one non-sensitive sample question.", state: contactCompleted ? .actionRequired : .waiting)
        }

        return [discovery, session, contact, implementation, execution]
    }

    public static func progress(for items: [NearBridgeReadinessItem]) -> Double {
        guard !items.isEmpty else { return 0 }
        return Double(items.filter { $0.state == .ready }.count) / Double(items.count)
    }

    public static func nextAction(for items: [NearBridgeReadinessItem]) -> String {
        items.first(where: { $0.state == .actionRequired })?.detail
            ?? items.first(where: { $0.state == .waiting })?.detail
            ?? "Demo path complete. Export sanitized diagnostics as review evidence."
    }
}

public enum NearBridgeReceiptOutcome: String, Codable, Equatable, Sendable {
    case requestSent
    case executing
    case succeeded
    case failed
}

public enum NearBridgeReceiptAcknowledgement: String, Codable, Equatable, Sendable {
    case pending
    case sent
    case received
}

public struct NearBridgeExecutionReceipt: Identifiable, Codable, Equatable, Sendable {
    public let invocationID: UUID
    public let capabilityID: String
    public let providerLabel: String
    public let peerFingerprint: String
    public let startedAt: Date
    public var completedAt: Date?
    public var outcome: NearBridgeReceiptOutcome
    public var integrity: String
    public var acknowledgement: NearBridgeReceiptAcknowledgement
    public var resultMessageID: UUID?

    public var id: UUID { invocationID }

    public var latencyMilliseconds: Double? {
        completedAt.map { $0.timeIntervalSince(startedAt) * 1_000 }
    }

    public init(
        invocationID: UUID,
        capabilityID: String,
        providerLabel: String,
        peerFingerprint: String,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        outcome: NearBridgeReceiptOutcome,
        integrity: String,
        acknowledgement: NearBridgeReceiptAcknowledgement = .pending,
        resultMessageID: UUID? = nil
    ) {
        self.invocationID = invocationID
        self.capabilityID = capabilityID
        self.providerLabel = providerLabel
        self.peerFingerprint = peerFingerprint
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.outcome = outcome
        self.integrity = integrity
        self.acknowledgement = acknowledgement
        self.resultMessageID = resultMessageID
    }
}

public enum NearBridgeSampleQuestions {
    public static let all = [
        "Explain in three short sentences why the sky appears blue during the day.",
        "Give me three practical ways to focus for twenty minutes without using personal data.",
        "Compare local and cloud AI in four concise bullet points."
    ]
}

public enum NearBridgeSafetyIdentifier {
    /// Build Week is a non-account preview. The authenticated session is therefore
    /// hashed into a stable, privacy-preserving identifier for that session.
    public static func forSession(_ sessionID: String) -> String {
        let digest = SHA256.hash(data: Data("nearbridge-preview:\(sessionID)".utf8))
        return "nb_" + digest.prefix(16).map { String(format: "%02x", $0) }.joined()
    }
}

public enum NearBridgeDiagnosticExport {
    public static func make(
        phase: NearBridgePhase,
        role: DeviceRole,
        readiness: [NearBridgeReadinessItem],
        receipt: NearBridgeExecutionReceipt?,
        events: [NearBridgeEvent]
    ) -> String {
        var lines = [
            "NearBridge sanitized review diagnostics",
            "phase: \(phase.displayName)",
            "role: \(role.rawValue)",
            "generatedAt: \(ISO8601DateFormatter().string(from: Date()))",
            "",
            "readiness:"
        ]
        lines.append(contentsOf: readiness.map { "- \($0.id): \($0.state.rawValue) — \($0.detail)" })
        if let receipt {
            lines.append("")
            lines.append("executionReceipt:")
            lines.append("- invocation: \(receipt.invocationID.uuidString)")
            lines.append("- capability: \(receipt.capabilityID)")
            lines.append("- provider: \(receipt.providerLabel)")
            lines.append("- peerFingerprint: \(receipt.peerFingerprint)")
            lines.append("- outcome: \(receipt.outcome.rawValue)")
            lines.append("- integrity: \(receipt.integrity)")
            lines.append("- acknowledgement: \(receipt.acknowledgement.rawValue)")
            if let latency = receipt.latencyMilliseconds {
                lines.append("- latencyMilliseconds: \(String(format: "%.1f", latency))")
            }
        }
        lines.append("")
        lines.append("eventsNewestFirst:")
        lines.append(contentsOf: events.prefix(100).map { "- \(sanitize($0.compactDescription))" })
        lines.append("")
        lines.append("Secrets, Authorization headers, and key-like tokens are intentionally redacted. Prompt and answer bodies are not included.")
        return sanitize(lines.joined(separator: "\n"))
    }

    public static func sanitize(_ value: String) -> String {
        var result = value
        let patterns = [
            #"(?i)Bearer\s+[A-Za-z0-9._~+\-/=]+"#,
            #"(?i)Authorization\s*:\s*[^\s]+"#,
            #"\bsk-[A-Za-z0-9_\-]{8,}\b"#
        ]
        for pattern in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = expression.stringByReplacingMatches(in: result, range: range, withTemplate: "[REDACTED]")
        }
        return result
    }
}
