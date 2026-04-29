// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SentinelPlatformiOS",
    platforms: [
        .iOS("26.2")
    ],
    products: [
        .library(
            name: "SentinelPlatformiOS",
            targets: ["SentinelPlatformiOS"]
        )
    ],
    dependencies: [
        .package(path: "../SentinelCore"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.25.2")
    ],
    targets: [
        .target(
            name: "SentinelPlatformiOS",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "SentinelCore", package: "SentinelCore")
            ],
            path: "Sources/SentinelPlatformiOS"
        )
    ]
)
