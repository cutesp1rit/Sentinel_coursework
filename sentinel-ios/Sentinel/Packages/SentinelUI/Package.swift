// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SentinelUI",
    platforms: [
        .iOS("26.2")
    ],
    products: [
        .library(
            name: "SentinelUI",
            targets: ["SentinelUI"]
        )
    ],
    targets: [
        .target(
            name: "SentinelUI",
            path: "Sources/SentinelUI"
        )
    ]
)
