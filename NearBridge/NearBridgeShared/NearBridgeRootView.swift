import Foundation
import SwiftUI

public struct NearBridgeRootView: View {
    @StateObject private var controller: NearBridgeController
    @Environment(\.scenePhase) private var scenePhase

    public init(role: DeviceRole) {
        _controller = StateObject(wrappedValue: NearBridgeController(role: role))
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Authenticated reliable messages", systemImage: "checkmark.shield")
                        .foregroundStyle(.orange)
                    Text("Discovery remains untrusted. Pair first; NB-3 then signs, expires, correlates, and deduplicates each message.")
                        .font(.caption)
                }

                Section("Checkpoint") {
                    LabeledContent("Phase", value: controller.phase.displayName)
                    LabeledContent("Automated", value: NearBridgeBuild.automatedStatus)
                    LabeledContent("Physical", value: NearBridgeBuild.physicalStatus)
                    if let identity = controller.localIdentity {
                        LabeledContent("Host identity", value: identity.fingerprint)
                    }
                    if let issue = controller.identityIssue {
                        Text(issue).font(.caption).foregroundStyle(.red)
                    }
                }

                Section("Discovery") {
                    HStack {
                        Button(controller.isRunning ? "Stop" : "Start") {
                            controller.isRunning ? controller.stop() : controller.start()
                        }
                        .buttonStyle(.borderedProminent)
                        Text(controller.discoveryState.rawValue)
                        Spacer()
                        Text(controller.localNetworkAccess.rawValue)
                            .foregroundStyle(controller.localNetworkAccess == .attentionRequired ? .orange : .secondary)
                    }
                    if controller.localNetworkAccess == .attentionRequired {
                        Text("Check Settings → Privacy & Security → Local Network and confirm that Wi-Fi is available.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Section("Untrusted nearby nodes") {
                    if controller.peers.isEmpty {
                        Text("No nodes discovered.").foregroundStyle(.secondary)
                    }
                    ForEach(controller.peers) { peer in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(peer.displayName)
                                Text("Ephemeral discovery reference · untrusted")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Pair") { controller.connect(to: peer) }
                                .buttonStyle(.bordered)
                                .disabled(controller.sessionState == .connecting || controller.sessionState == .connected)
                        }
                    }
                }

                Section("Pairing channel") {
                    LabeledContent("Session", value: controller.sessionState.rawValue)
                    LabeledContent("Authentication", value: controller.authenticatedSessionState.rawValue)
                    if let pairing = controller.pendingPairing {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(pairing.displayName).bold()
                            Text("Fingerprint \(pairing.fingerprint)").font(.caption)
                            Text(pairing.verificationCode)
                                .font(.system(.title, design: .monospaced, weight: .bold))
                                .textSelection(.enabled)
                            Text(pairing.state.rawValue).font(.caption).foregroundStyle(.secondary)
                            if pairing.state == .awaitingLocalApproval {
                                HStack {
                                    Button("Codes match — Approve") { controller.approvePairing() }
                                        .buttonStyle(.borderedProminent)
                                    Button("Reject", role: .destructive) { controller.rejectPairing() }
                                        .buttonStyle(.bordered)
                                }
                            }
                            if pairing.state == .awaitingRemoteConfirmation {
                                Text("Local approval recorded. Waiting for the other device.")
                                    .font(.caption)
                            }
                            if pairing.state == .established {
                                Label("Paired and stored by this Host", systemImage: "checkmark.shield.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    } else {
                        Text("Select Pair on one device. A stranger cannot become trusted without confirmation.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if controller.sessionState == .connected {
                        Button("Disconnect", role: .destructive) { controller.disconnect() }
                            .buttonStyle(.bordered)
                    }
                }

                Section("Authenticated messages") {
                    Button("Send signed ping") { controller.sendAuthenticatedPing() }
                        .buttonStyle(.borderedProminent)
                        .disabled(controller.authenticatedSessionState != .authenticated || controller.pendingPingCount > 0)
                    if let sent = controller.lastSentMessage {
                        LabeledContent("Last sent", value: "\(sent.messageType.rawValue) #\(sent.payload.sequence)")
                    }
                    if let received = controller.lastReceivedMessage {
                        LabeledContent("Last received", value: "\(received.messageType.rawValue) #\(received.payload.sequence)")
                    }
                    if let milliseconds = controller.roundTripMilliseconds {
                        LabeledContent("Round trip", value: String(format: "%.1f ms", milliseconds))
                    }
                    Text("Messages are signed and bound to this fresh session. NB-3 does not claim payload encryption.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Paired nodes") {
                    if controller.pairedNodes.isEmpty {
                        Text("No paired nodes.").foregroundStyle(.secondary)
                    }
                    ForEach(controller.pairedNodes) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.displayName)
                                Text("\(record.role.rawValue) · \(record.fingerprint)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Revoke", role: .destructive) { controller.revoke(record) }
                                .buttonStyle(.bordered)
                        }
                    }
                }

                Section("Structured diagnostics") {
                    if controller.events.isEmpty {
                        Text("No events yet.").foregroundStyle(.secondary)
                    }
                    ForEach(controller.events) { event in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(event.category.rawValue) · \(event.state)").font(.caption).bold()
                            Text(event.humanReadableDetail).font(.caption)
                            if let domain = event.errorDomain, let code = event.errorCode {
                                Text("Error: \(domain) (\(code))").font(.caption).foregroundStyle(.red)
                            }
                            Text(event.compactDescription)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .navigationTitle("NearBridge \(controller.phase.displayName)")
        }
        .task { controller.start() }
        .onChange(of: scenePhase) { _, newPhase in
            controller.recordLifecycle(String(describing: newPhase))
        }
    }
}
