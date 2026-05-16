// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "StatBar",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "StatBarCore", targets: ["StatBarCore"]),
        .executable(name: "StatBar", targets: ["StatBar"])
    ],
    targets: [
        .target(name: "StatBarCore"),
        .executableTarget(
            name: "StatBar",
            dependencies: ["StatBarCore"]
        ),
        .testTarget(
            name: "StatBarCoreTests",
            dependencies: ["StatBarCore"]
        )
    ]
)
