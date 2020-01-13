// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "XPM",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(name: "xpm", targets: ["XPM"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-tools-support-core", .branch("master")),
        .package(url: "https://github.com/vapor/console-kit.git", from: "4.0.0-beta.2"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.2.0")
    ],
    targets: [
        .target(
            name: "XPM",
            dependencies: ["XPMKit", "SwiftToolsSupport-auto", "ConsoleKit"]
        ),
        .target(
            name: "XPMKit",
            dependencies: ["SwiftToolsSupport-auto", "Logging"]
        ),
        .testTarget(
            name: "XPMKitTests",
            dependencies: ["XPMKit"]
        ),
        .testTarget(
            name: "XPMTests",
            dependencies: ["SwiftToolsSupport-auto"]
        ),
    ]
)
