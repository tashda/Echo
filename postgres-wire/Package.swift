// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "postgres-wire",
    platforms: [ .macOS(.v13) ],
    products: [
        .library(name: "PostgresWire", targets: ["PostgresWire"]),
        .library(name: "PostgresKit", targets: ["PostgresKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.29.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-metrics.git", from: "2.3.0")
    ],
    targets: [
        .target(
            name: "PostgresWire",
            dependencies: [
                .product(name: "PostgresNIO", package: "postgres-nio"),
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .target(
            name: "PostgresKit",
            dependencies: [
                "PostgresWire",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Metrics", package: "swift-metrics")
            ]
        ),
        .testTarget(
            name: "PostgresKitTests",
            dependencies: ["PostgresKit"]
        )
    ]
)

