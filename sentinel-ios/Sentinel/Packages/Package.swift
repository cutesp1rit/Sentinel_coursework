// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SentinelModules",
    platforms: [
        .iOS("26.2")
    ],
    products: [
        .library(
            name: "SentinelUI",
            targets: ["SentinelUI"]
        ),
        .library(
            name: "SentinelCore",
            targets: ["SentinelCore"]
        ),
        .library(
            name: "SentinelPlatformiOS",
            targets: ["SentinelPlatformiOS"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.25.2")
    ],
    targets: [
        .target(
            name: "SentinelUI",
            path: "Sources/SentinelUI"
        ),
        .target(
            name: "SentinelCore",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ],
            path: "Sources/SentinelCore"
        ),
        .target(
            name: "SentinelPlatformiOS",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                "SentinelCore"
            ],
            path: "Sources/SentinelPlatformiOS"
        )
    ]
)
