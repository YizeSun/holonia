import SwiftUI

public struct NearBridgeExperimentView: View {
    @StateObject private var controller: ExperimentController
    @Environment(\.scenePhase) private var scenePhase

    public init(role: DeviceRole) {
        _controller = StateObject(wrappedValue: ExperimentController(role: role))
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Untrusted transport experiment", systemImage: "exclamationmark.shield")
                        .foregroundStyle(.orange)
                    Text("Discovery is not authentication. NB-0 exchanges only non-sensitive ping/pong data.")
                        .font(.caption)
                }

                Section("Experiment") {
                    Picker("Candidate", selection: Binding(
                        get: { controller.selectedExperiment },
                        set: { controller.select($0) }
                    )) {
                        ForEach(ExperimentKind.allCases) { experiment in
                            Text(experiment.rawValue).tag(experiment)
                        }
                    }
                    HStack {
                        Button(controller.isRunning ? "Stop" : "Start") {
                            controller.isRunning ? controller.stop() : controller.start()
                        }
                        .buttonStyle(.borderedProminent)
                        Text("Discovery: \(controller.discoveryState.rawValue)")
                        Spacer()
                        Text("Session: \(controller.sessionState.rawValue)")
                    }
                }

                Section("Discovered peers") {
                    if controller.peers.isEmpty {
                        Text(controller.selectedExperiment == .udpMulticastProbe ? "UDP peers appear only as diagnostic datagrams." : "No peers discovered.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(controller.peers) { peer in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(peer.displayName)
                                Text(peer.endpointDescription).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Connect") { controller.connect(to: peer) }
                                .disabled(
                                    !controller.selectedExperiment.supportsSessions ||
                                    [.connecting, .connected, .disconnecting, .reconnecting].contains(controller.sessionState)
                                )
                        }
                    }
                }

                Section("Session") {
                    HStack {
                        Button(controller.pendingPingCount == 0 ? "Send ping" : "Waiting for pong…") { controller.sendPing() }
                            .buttonStyle(.borderedProminent)
                            .disabled(
                                !controller.isRunning ||
                                controller.pendingPingCount > 0 ||
                                (controller.selectedExperiment.supportsSessions && controller.sessionState != .connected)
                            )
                        Button("Disconnect", role: .destructive) { controller.disconnect() }
                            .buttonStyle(.bordered)
                            .disabled(controller.sessionState != .connected)
                    }
                    if let message = controller.lastSentMessage {
                        Text("Last sent: \(message.messageType.rawValue) #\(message.payload.sequence)")
                    }
                    if let message = controller.lastReceivedMessage {
                        Text("Last received: \(message.messageType.rawValue) #\(message.payload.sequence)")
                    }
                    if let roundTrip = controller.roundTripMilliseconds {
                        Text("Last round trip: \(roundTrip, format: .number.precision(.fractionLength(1))) ms")
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
                            Text(event.compactDescription).font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    }
                }
            }
            .navigationTitle("NearBridge NB-0")
        }
        .onChange(of: scenePhase) { _, newPhase in
            controller.recordLifecycle(String(describing: newPhase))
        }
    }
}
