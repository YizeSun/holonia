import NearBridgeShared
import SwiftUI

@main
struct NearBridgeIOSApp: App {
    var body: some Scene {
        WindowGroup {
            NearBridgeExperimentView(role: .iPhone)
        }
    }
}
