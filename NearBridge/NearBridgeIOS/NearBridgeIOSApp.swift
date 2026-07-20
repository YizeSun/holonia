import NearBridgeShared
import SwiftUI

@main
struct NearBridgeIOSApp: App {
    var body: some Scene {
        WindowGroup {
            NearBridgeRootView(role: .iPhone)
        }
    }
}
