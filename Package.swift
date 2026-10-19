// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FLowmo",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "FLowmo", targets: ["FLowmo"])],
    targets: [
        .target(name: "FLowmoCore"),
        .executableTarget(name: "FLowmo", dependencies: ["FLowmoCore"]),
        .testTarget(name: "FLowmoCoreTests", dependencies: ["FLowmoCore"]),
        .testTarget(name: "FLowmoAppTests", dependencies: ["FLowmo"])
    ]
)
