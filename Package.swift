// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LinkPort",
    defaultLocalization: "en",
    platforms: [.macOS(.v26)],
    products: [.executable(name: "LinkPort", targets: ["LinkPort"])],
    targets: [
        .target(name: "LinkPortCore"),
        .executableTarget(
            name: "LinkPort",
            dependencies: ["LinkPortCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "LinkPortCoreTests", dependencies: ["LinkPortCore"]),
        .testTarget(name: "LinkPortTests", dependencies: ["LinkPort", "LinkPortCore"]),
    ]
)
