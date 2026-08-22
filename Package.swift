// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "QuotAICore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "QuotAICore", targets: ["QuotAICore"])
    ],
    targets: [
        .target(
            name: "QuotAICore",
            path: "Core"
        ),
        .testTarget(
            name: "QuotAICoreTests",
            dependencies: ["QuotAICore"],
            path: "Tests/CoreTests"
        )
    ]
)
