import Foundation
import SwiftUI

public struct NearBridgeRootView: View {
    @StateObject private var controller: NearBridgeController
    @State private var capabilityInput = "NearBridge lets an iPhone discover and pair with a Mac. The Mac Host exposes only registered capabilities. Signed messages preserve sender, session, expiry, and integrity."
    @State private var openAIAPIKeyDraft = ""
    @Environment(\.scenePhase) private var scenePhase

    public init(role: DeviceRole) {
        _controller = StateObject(wrappedValue: NearBridgeController(role: role))
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Remote model-only checkpoint", systemImage: "network.badge.shield.half.filled")
                        .foregroundStyle(.orange)
                    Text("NB-9 lets an authenticated iPhone ask a Mac-selected OpenAI model through a separate app-sandboxed network XPC runner. The fixed request sends plain text only with store disabled and no tools, files, workspace, commands, or Codex App/CLI authority.")
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

                Section("Primary Holon implementation") {
                    if controller.role == .mac, let selected = controller.selectedPrimaryHolon {
                        Picker(
                            "Implementation",
                            selection: Binding(
                                get: { controller.selectedPrimaryHolon?.implementationID ?? selected.implementationID },
                                set: { controller.selectPrimaryHolon(implementationID: $0) }
                            )
                        ) {
                            ForEach(controller.availablePrimaryHolons) { implementation in
                                Text(implementation.displayName).tag(implementation.implementationID)
                            }
                        }
                        .disabled(controller.primaryHolonSelectionLocked)
                        LabeledContent("Adapter", value: selected.adapterLabel)
                        LabeledContent("Runtime", value: selected.runtime.rawValue)
                        LabeledContent("Real model", value: selected.usesRealModel ? "yes" : "no · deterministic")
                        LabeledContent("Location", value: selected.executionProfile.networkPolicy == .denied ? "on-device" : "remote provider")
                        LabeledContent("Isolation", value: selected.executionProfile.isolationBoundary.rawValue)
                        LabeledContent("Network", value: selected.executionProfile.networkPolicy.rawValue)
                        Text(selected.modelDisclosure)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(selected.implementationID)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        if controller.primaryHolonSelectionLocked {
                            Text("Disconnect before changing the Host implementation so the active contact and capability contract cannot change mid-session.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    } else {
                        Text("The iPhone does not select or execute the Mac Primary Holon. It can request only the fixed, signed text-insight capability after authentication and contact approval.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if controller.role == .mac {
                    Section("OpenAI model-only credential") {
                        LabeledContent("Status", value: controller.openAIAPIKeyConfigured ? "configured in Host Keychain" : "not configured")
                        SecureField("OpenAI API key", text: $openAIAPIKeyDraft)
                            .privacySensitive()
                        HStack {
                            Button("Save to Keychain") {
                                if controller.saveOpenAIAPIKey(openAIAPIKeyDraft) {
                                    openAIAPIKeyDraft = ""
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(
                                openAIAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                controller.capabilityExecutionState == .executing
                            )
                            if controller.openAIAPIKeyConfigured {
                                Button("Remove key", role: .destructive) {
                                    controller.removeOpenAIAPIKey()
                                    openAIAPIKeyDraft = ""
                                }
                                .buttonStyle(.bordered)
                                .disabled(controller.capabilityExecutionState == .executing)
                            }
                        }
                        if let issue = controller.openAICredentialIssue {
                            Text(issue).font(.caption).foregroundStyle(.red)
                        }
                        if controller.selectedPrimaryHolon?.implementationID == PrimaryHolonImplementationID.openAIModelOnly,
                           !controller.openAIAPIKeyConfigured {
                            Text("The selected remote Primary Holon will reject requests until a key is configured here.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        Text("Enter the key only in this Mac App, never in an iPhone prompt or chat. The Host does not display it again. It is passed in memory to a network-only XPC runner and is never sent to the iPhone or included in diagnostics.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                        LabeledContent("Last sent", value: sent.displaySummary)
                    }
                    if let received = controller.lastReceivedMessage {
                        LabeledContent("Last received", value: received.displaySummary)
                    }
                    if let milliseconds = controller.roundTripMilliseconds {
                        LabeledContent("Round trip", value: String(format: "%.1f ms", milliseconds))
                    }
                    Text("Messages are signed and bound to this fresh session. NB-3 does not claim payload encryption.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Contact demo") {
                    LabeledContent("State", value: controller.contactWorkflowState.rawValue)
                    if let summary = controller.contactWorkflowSummary {
                        Text(summary).font(.caption)
                    }
                    switch controller.contactWorkflowState {
                    case .idle:
                        if controller.role == .iPhone {
                            Button("Request Primary Holon contact") { controller.startContactRequest() }
                                .buttonStyle(.borderedProminent)
                                .disabled(controller.authenticatedSessionState != .authenticated)
                        } else {
                            Text("Waiting for an authenticated iPhone request.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    case .requestReceived:
                        if controller.role == .mac {
                            Button("Respond: capability available") { controller.sendCapabilityResponse() }
                                .buttonStyle(.borderedProminent)
                        }
                    case .responseReceived:
                        if controller.role == .iPhone {
                            Button("Accept contact") { controller.acceptContact() }
                                .buttonStyle(.borderedProminent)
                        }
                    case .acceptanceReceived:
                        if controller.role == .mac {
                            Button("Mark contact completed") { controller.completeContact() }
                                .buttonStyle(.borderedProminent)
                        }
                    case .completed:
                        Label("Contact flow completed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .requestSent, .responseSent, .acceptanceSent:
                        Text("Waiting for the paired device.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("This demo exchanges signed workflow messages only. No repository, model, tool, or remote command is accessed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("NB-9 Primary Holon question demo") {
                    if controller.registeredCapabilities.isEmpty {
                        Text("This device registers no executable capability.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(controller.registeredCapabilities) { capability in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(capability.displayName).bold()
                                Text(capability.capabilityID).font(.caption2).textSelection(.enabled)
                                Text(capability.executorLabel).font(.caption).foregroundStyle(.secondary)
                                Text("Host allowlist · input ≤ \(capability.maximumInputCharacters) · output ≤ \(capability.maximumOutputCharacters)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    if controller.role == .iPhone {
                        TextEditor(text: $capabilityInput)
                            .frame(minHeight: 100)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3)))
                        Text("\(capabilityInput.count) / 1200 characters")
                            .font(.caption2)
                            .foregroundStyle(capabilityInput.count > 1_200 ? .red : .secondary)
                        Button("Ask selected Mac Primary Holon") {
                            controller.invokePrimaryHolon(input: capabilityInput)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(
                            controller.authenticatedSessionState != .authenticated ||
                            controller.contactWorkflowState != .completed ||
                            capabilityInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            capabilityInput.count > 1_200
                        )
                    }
                    LabeledContent("Execution", value: controller.capabilityExecutionState.rawValue)
                    if let output = controller.lastCapabilityOutput {
                        Text(output).textSelection(.enabled)
                    }
                    Text("Adapter role: receive inert text after Host policy checks, run one compile-time allowlisted handler, and return a signed typed result. Payload encryption is still not claimed; do not enter secrets.")
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
