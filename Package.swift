// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ImmichJobQueueVisualizer",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "ImmichJobQueueVisualizer",
            targets: ["ImmichJobQueueVisualizer"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.14.1")
    ],
    targets: [
        .executableTarget(
            name: "ImmichJobQueueVisualizer",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            path: "Sources/ImmichJobQueueVisualizer"
        )
    ]
)
