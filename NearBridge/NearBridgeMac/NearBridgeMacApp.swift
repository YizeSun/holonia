import NearBridgeShared
import SwiftUI

@main
struct NearBridgeMacApp: App {
    var body: some Scene {
        WindowGroup {
            NearBridgeRootView(role: .mac)
                .frame(minWidth: 760, minHeight: 640)
        }
    }
}
