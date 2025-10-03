// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RevenueCore",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(name: "RevenueCore", targets: ["RevenueCore"]),
    ],
    dependencies: [
        // Add external dependencies here if needed
    ],
    targets: [
        .target(
            name: "RevenueCore",
            dependencies: [],
            path: "Sources/RevenueCore"
        ),
        .testTarget(
            name: "RevenueCoreTests",
            dependencies: ["RevenueCore"],
            path: "Tests/RevenueCoreTests"
        )
    ]
)
