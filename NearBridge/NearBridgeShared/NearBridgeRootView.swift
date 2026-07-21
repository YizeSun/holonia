import Foundation
import SwiftUI

public struct NearBridgeRootView: View {
    @StateObject private var controller: NearBridgeController
    @State private var presentationMode: NearBridgePresentationMode = .demo
    @State private var capabilityInput = NearBridgeSampleQuestions.all[0]
    @State private var openAIAPIKeyDraft = ""
    @Environment(\.scenePhase) private var scenePhase

    public init(role: DeviceRole) {
        _controller = StateObject(wrappedValue: NearBridgeController(role: role))
    }

    public var body: some View {
        NavigationStack {
            Group {
                switch presentationMode {
                case .demo:
                    NearBridgeDemoView(
                        controller: controller,
                        capabilityInput: $capabilityInput,
                        openAIAPIKeyDraft: $openAIAPIKeyDraft
                    )
                case .diagnostics:
                    NearBridgeDiagnosticsView(
                        controller: controller,
                        openAIAPIKeyDraft: $openAIAPIKeyDraft
                    )
                }
            }
            .navigationTitle("NearBridge \(controller.phase.displayName)")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("View", selection: $presentationMode) {
                        ForEach(NearBridgePresentationMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 280)
                }
            }
        }
        .task { controller.start() }
        .onChange(of: scenePhase) { _, newPhase in
            controller.recordLifecycle(String(describing: newPhase))
        }
    }
}

private struct NearBridgeDemoView: View {
    @ObservedObject var controller: NearBridgeController
    @Binding var capabilityInput: String
    @Binding var openAIAPIKeyDraft: String

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label("A stronger model, reached from the device in your hand", systemImage: "iphone.and.arrow.forward")
                        .font(.headline)
                        .foregroundStyle(.tint)
                    Text("iPhone → authenticated local session → Mac Host policy → selected Primary Holon → signed answer")
                        .font(.subheadline)
                    Text("Discovery is not authentication. NearBridge sends only the non-sensitive text you explicitly submit; it exposes no files, shell, workspace, dynamic tools, or Codex App login.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Demo readiness") {
                ProgressView(value: controller.reviewReadinessProgress) {
                    Text("\(Int(controller.reviewReadinessProgress * 100))% ready")
                }
                Text(controller.nextRecommendedAction)
                    .font(.subheadline)
                    .foregroundStyle(.tint)
                ForEach(controller.reviewReadiness) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: readinessIcon(item.state))
                            .foregroundStyle(readinessColor(item.state))
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).font(.subheadline).bold()
                            Text(item.detail).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if controller.role == .mac {
                Section("Mac Primary Holon") {
                    PrimaryHolonPicker(controller: controller)
                    OpenAICredentialEditor(
                        controller: controller,
                        openAIAPIKeyDraft: $openAIAPIKeyDraft,
                        compact: true
                    )
                }
            } else if let disclosure = controller.remotePrimaryHolonDisclosure {
                Section("Mac Primary Holon") {
                    Label("Host disclosure received", systemImage: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                    Text(disclosure).font(.caption)
                }
            }

            Section("1 · Discover and authenticate") {
                DiscoveryControls(controller: controller)
                PeerRows(controller: controller)
                PairingControls(controller: controller)
            }

            Section("2 · Approve one narrow capability") {
                ContactControls(controller: controller)
            }

            Section("3 · Ask the selected Mac Primary Holon") {
                if controller.role == .iPhone {
                    Text("Choose a safe sample or type a plain-text question.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(Array(NearBridgeSampleQuestions.all.enumerated()), id: \.offset) { index, question in
                        Button("Sample \(index + 1): \(sampleTitle(question))") {
                            capabilityInput = question
                        }
                        .buttonStyle(.borderless)
                    }
                    TextEditor(text: $capabilityInput)
                        .frame(minHeight: 110)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.secondary.opacity(0.35)))
                    Text("\(capabilityInput.count) / 1,200 characters · do not enter secrets")
                        .font(.caption2)
                        .foregroundStyle(capabilityInput.count > 1_200 ? .red : .secondary)
                    Button(controller.capabilityExecutionState == .failed ? "Retry question" : "Ask Mac Primary Holon") {
                        controller.invokePrimaryHolon(input: capabilityInput)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canInvoke)
                } else {
                    Text("The Mac waits for the authenticated iPhone request, applies the Host allowlist, then runs only the selected adapter.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Execution", value: controller.capabilityExecutionState.rawValue)
                if let output = controller.lastCapabilityOutput {
                    Text(output)
                        .textSelection(.enabled)
                        .foregroundStyle(controller.capabilityExecutionState == .failed ? .red : .primary)
                }
            }

            if let receipt = controller.lastExecutionReceipt {
                Section("Execution receipt") {
                    LabeledContent("Outcome", value: receipt.outcome.rawValue)
                    LabeledContent("Provider", value: receipt.providerLabel)
                    LabeledContent("Peer", value: receipt.peerFingerprint)
                    LabeledContent("Capability", value: receipt.capabilityID)
                    LabeledContent("Integrity", value: receipt.integrity)
                    LabeledContent("Acknowledgement", value: receipt.acknowledgement.rawValue)
                    if let latency = receipt.latencyMilliseconds {
                        LabeledContent("End-to-end", value: String(format: "%.1f ms", latency))
                    }
                    Text("Invocation \(receipt.invocationID.uuidString)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            Section("Safety boundary") {
                Label("Model-only, bounded and user initiated", systemImage: "checkmark.shield")
                    .foregroundStyle(.green)
                Text("Input ≤ 1,200 characters. Output ≤ 4,000 characters. OpenAI requests use store: false, omit tools, and include a privacy-preserving session safety identifier. Model output can be wrong; verify important answers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("Select Diagnostics above to inspect events or export a sanitized report.", systemImage: "doc.text.magnifyingglass")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var canInvoke: Bool {
        controller.authenticatedSessionState == .authenticated &&
        controller.contactWorkflowState == .completed &&
        controller.capabilityExecutionState != .executing &&
        controller.capabilityExecutionState != .requestSent &&
        !capabilityInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        capabilityInput.count <= 1_200
    }

    private func sampleTitle(_ question: String) -> String {
        if question.contains("sky") { return "Why is the sky blue?" }
        if question.contains("focus") { return "A short focus plan" }
        return "Local AI vs cloud AI"
    }

    private func readinessIcon(_ state: NearBridgeReadinessState) -> String {
        switch state {
        case .ready: return "checkmark.circle.fill"
        case .waiting: return "clock.fill"
        case .actionRequired: return "arrow.right.circle.fill"
        }
    }

    private func readinessColor(_ state: NearBridgeReadinessState) -> Color {
        switch state {
        case .ready: return .green
        case .waiting: return .secondary
        case .actionRequired: return .orange
        }
    }
}

private struct NearBridgeDiagnosticsView: View {
    @ObservedObject var controller: NearBridgeController
    @Binding var openAIAPIKeyDraft: String

    var body: some View {
        List {
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
                ShareLink(item: controller.sanitizedDiagnostics) {
                    Label("Export sanitized diagnostics", systemImage: "square.and.arrow.up")
                }
                Text("The export excludes prompt and answer bodies and redacts key-like values and authorization headers.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if controller.role == .mac {
                Section("Primary Holon implementation") {
                    PrimaryHolonPicker(controller: controller)
                    OpenAICredentialEditor(
                        controller: controller,
                        openAIAPIKeyDraft: $openAIAPIKeyDraft,
                        compact: false
                    )
                }
            }

            Section("Discovery and session") {
                DiscoveryControls(controller: controller)
                PeerRows(controller: controller)
                PairingControls(controller: controller)
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
            }

            Section("Contact and capability") {
                ContactControls(controller: controller)
                LabeledContent("Execution", value: controller.capabilityExecutionState.rawValue)
                if let output = controller.lastCapabilityOutput {
                    Text(output).textSelection(.enabled)
                }
                ForEach(controller.registeredCapabilities) { capability in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(capability.displayName).bold()
                        Text(capability.capabilityID).font(.caption2).textSelection(.enabled)
                        Text("\(capability.executorLabel) · input ≤ \(capability.maximumInputCharacters) · output ≤ \(capability.maximumOutputCharacters)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Paired nodes") {
                if controller.pairedNodes.isEmpty {
                    Text("No paired nodes.").foregroundStyle(.secondary)
                }
                ForEach(controller.pairedNodes) { record in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(record.displayName)
                            Text("\(record.role.rawValue) · \(record.fingerprint)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Revoke", role: .destructive) { controller.revoke(record) }
                    }
                }
            }

            Section("Structured diagnostics · newest first") {
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
    }
}

private struct PrimaryHolonPicker: View {
    @ObservedObject var controller: NearBridgeController

    var body: some View {
        if let selected = controller.selectedPrimaryHolon {
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
            LabeledContent("Isolation", value: selected.executionProfile.isolationBoundary.rawValue)
            LabeledContent("Network", value: selected.executionProfile.networkPolicy.rawValue)
            Text(selected.modelDisclosure).font(.caption).foregroundStyle(.secondary)
        } else {
            Text("No Primary Holon implementation is selected.").foregroundStyle(.orange)
        }
    }
}

private struct OpenAICredentialEditor: View {
    @ObservedObject var controller: NearBridgeController
    @Binding var openAIAPIKeyDraft: String
    let compact: Bool

    var body: some View {
        if controller.selectedPrimaryHolon?.implementationID == PrimaryHolonImplementationID.openAIModelOnly || !compact {
            LabeledContent("OpenAI key", value: controller.openAIAPIKeyConfigured ? "configured in Host Keychain" : "not configured")
            SecureField("OpenAI API key", text: $openAIAPIKeyDraft)
                .privacySensitive()
            HStack {
                Button("Save to Keychain") {
                    if controller.saveOpenAIAPIKey(openAIAPIKeyDraft) { openAIAPIKeyDraft = "" }
                }
                .buttonStyle(.borderedProminent)
                .disabled(openAIAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || controller.capabilityExecutionState == .executing)
                if controller.openAIAPIKeyConfigured {
                    Button("Remove", role: .destructive) {
                        controller.removeOpenAIAPIKey()
                        openAIAPIKeyDraft = ""
                    }
                    .disabled(controller.capabilityExecutionState == .executing)
                }
            }
            if let issue = controller.openAICredentialIssue {
                Text(issue).font(.caption).foregroundStyle(.red)
            }
            Text("The secret stays in the Mac Host Keychain and is never shown to the iPhone or included in diagnostics.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct DiscoveryControls: View {
    @ObservedObject var controller: NearBridgeController

    var body: some View {
        HStack {
            Button(controller.isRunning ? "Stop" : "Start") {
                controller.isRunning ? controller.stop() : controller.start()
            }
            .buttonStyle(.borderedProminent)
            VStack(alignment: .leading, spacing: 2) {
                Text(controller.discoveryState.rawValue)
                Text(controller.localNetworkAccess.rawValue)
                    .font(.caption2)
                    .foregroundStyle(controller.localNetworkAccess == .attentionRequired ? .orange : .secondary)
            }
            Spacer()
            if controller.sessionState == .connected {
                Label("Connected", systemImage: "link.circle.fill").foregroundStyle(.green)
            }
        }
        if controller.localNetworkAccess == .attentionRequired {
            Text("Enable Settings → Privacy & Security → Local Network, then restart the app.")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}

private struct PeerRows: View {
    @ObservedObject var controller: NearBridgeController

    var body: some View {
        if controller.peers.isEmpty && controller.sessionState != .connected {
            Text("Waiting for a nearby iPhone or Mac on the same Wi-Fi.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        ForEach(controller.peers) { peer in
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(peer.displayName)
                    Text("Discovered only · not authenticated")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Pair") { controller.connect(to: peer) }
                    .disabled([.connecting, .connected, .reconnecting].contains(controller.sessionState))
            }
        }
    }
}

private struct PairingControls: View {
    @ObservedObject var controller: NearBridgeController

    var body: some View {
        LabeledContent("Session", value: controller.sessionState.rawValue)
        LabeledContent("Authentication", value: controller.authenticatedSessionState.rawValue)
        if let pairing = controller.pendingPairing {
            VStack(alignment: .leading, spacing: 8) {
                Text(pairing.displayName).bold()
                Text("Fingerprint \(pairing.fingerprint)").font(.caption)
                Text(pairing.verificationCode)
                    .font(.system(.title, design: .monospaced, weight: .bold))
                    .textSelection(.enabled)
                if pairing.state == .awaitingLocalApproval {
                    HStack {
                        Button("Codes match — Approve") { controller.approvePairing() }
                            .buttonStyle(.borderedProminent)
                        Button("Reject", role: .destructive) { controller.rejectPairing() }
                    }
                } else if pairing.state == .awaitingRemoteConfirmation {
                    Text("Approved here. Waiting for the other device.").font(.caption)
                } else if pairing.state == .established {
                    Label("Paired and stored by this Host", systemImage: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        if controller.sessionState == .connected {
            Button("Disconnect", role: .destructive) { controller.disconnect() }
        }
    }
}

private struct ContactControls: View {
    @ObservedObject var controller: NearBridgeController

    var body: some View {
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
                Text("Waiting for the authenticated iPhone request.").font(.caption).foregroundStyle(.secondary)
            }
        case .requestReceived:
            if controller.role == .mac {
                Button("Respond: capability available") { controller.sendCapabilityResponse() }
                    .buttonStyle(.borderedProminent)
            }
        case .responseReceived:
            if controller.role == .iPhone {
                Button("Accept capability contact") { controller.acceptContact() }
                    .buttonStyle(.borderedProminent)
            }
        case .acceptanceReceived:
            if controller.role == .mac {
                Button("Complete approved contact") { controller.completeContact() }
                    .buttonStyle(.borderedProminent)
            }
        case .completed:
            Label("Signed capability contact complete", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .requestSent, .responseSent, .acceptanceSent:
            Text("Waiting for the paired device.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
