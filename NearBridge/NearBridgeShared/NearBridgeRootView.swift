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
                    Label("Untrusted discovery", systemImage: "dot.radiowaves.left.and.right")
                        .foregroundStyle(.orange)
                    Text("A discovered device is only a nearby candidate. Pairing and identity start in NB-2.")
                        .font(.caption)
                }

                Section("Checkpoint") {
                    LabeledContent("Phase", value: controller.phase.displayName)
                    LabeledContent("Automated", value: NearBridgeBuild.automatedStatus)
                    LabeledContent("Physical", value: NearBridgeBuild.physicalStatus)
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
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(peer.displayName)
                                Spacer()
                                Text(peer.trustState.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            Text(peer.discoveryReference)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("Ephemeral discovery reference · no capabilities advertised")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
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
