// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacClientSupport",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "EngineCore",
            targets: ["EngineCore"]
        ),
    ],
    targets: [
        .target(
            name: "EngineCore",
            path: "Pindrop/Services/EngineSupport"
        ),
        .testTarget(
            name: "EngineCoreTests",
            dependencies: ["EngineCore"]
        ),
    ]
)
