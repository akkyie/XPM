// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "Example",
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire", from: "5.0.0-rc.3"), // Simple but large
        .package(url: "https://github.com/groue/GRDB.swift", from: "4.7.0"), // Depends on system library
        .package(url: "https://github.com/Moya/Moya", from: "14.0.0-beta.6"), // Multi-product, depends on Alamofire
    ],
    targets: [
        .target(
            name: "Example1",
            dependencies: ["Alamofire"]
        ),
        .target(
            name: "Example2",
            dependencies: ["Alamofire", "GRDB", "Moya"]
        ),
    ]
)
