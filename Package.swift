// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexIndicatorCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CodexIndicatorCore", targets: ["CodexIndicatorCore"])
    ],
    targets: [
        .target(
            name: "CodexIndicatorCore",
            path: "Core"
        ),
        .testTarget(
            name: "CodexIndicatorCoreTests",
            dependencies: ["CodexIndicatorCore"],
            path: "Tests/CoreTests"
        )
    ]
)
