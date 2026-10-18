// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Flosted",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Flosted", targets: ["Flosted"])],
    targets: [
        .target(name: "FlostedCore"),
        .executableTarget(name: "Flosted", dependencies: ["FlostedCore"]),
        .testTarget(name: "FlostedCoreTests", dependencies: ["FlostedCore"]),
        .testTarget(name: "FlostedAppTests", dependencies: ["Flosted"])
    ]
)
