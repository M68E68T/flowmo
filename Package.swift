// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "flowmo",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "flowmo", targets: ["Flowmo"])],
    targets: [
        .target(name: "FlowmoCore"),
        .executableTarget(name: "Flowmo", dependencies: ["FlowmoCore"]),
        .testTarget(name: "FlowmoCoreTests", dependencies: ["FlowmoCore"]),
        .testTarget(name: "FlowmoAppTests", dependencies: ["Flowmo"])
    ]
)
