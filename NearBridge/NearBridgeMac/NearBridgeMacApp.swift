import NearBridgeShared
import SwiftUI

@main
struct NearBridgeMacApp: App {
    var body: some Scene {
        WindowGroup {
            NearBridgeExperimentView(role: .mac)
                .frame(minWidth: 760, minHeight: 640)
        }
    }
}
