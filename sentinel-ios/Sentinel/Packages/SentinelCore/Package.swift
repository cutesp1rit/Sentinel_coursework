// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SentinelCore",
    platforms: [
        .iOS("26.2")
    ],
    products: [
        .library(
            name: "SentinelCore",
            targets: ["SentinelCore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.25.2")
    ],
    targets: [
        .target(
            name: "SentinelCore",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ],
            path: "Sources/SentinelCore"
        )
    ]
)
