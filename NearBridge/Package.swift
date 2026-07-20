// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NearBridgeShared",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "NearBridgeShared", targets: ["NearBridgeShared"])
    ],
    targets: [
        .target(
            name: "NearBridgeShared",
            path: "NearBridgeShared"
        ),
        .testTarget(
            name: "NearBridgeSharedTests",
            dependencies: ["NearBridgeShared"],
            path: "NearBridgeSharedTests"
        )
    ]
)
