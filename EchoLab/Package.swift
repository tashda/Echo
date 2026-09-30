// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "EchoLab",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../Packages/EchoDesignSystem"),
        .package(path: "../../EchoSense"),
        .package(path: "../../postgres-wire"),
        .package(path: "../../sqlserver-nio")
    ],
    targets: [
        .executableTarget(
            name: "EchoLab",
            dependencies: [
                .product(name: "EchoDesignSystem", package: "EchoDesignSystem"),
                .product(name: "EchoSense", package: "EchoSense"),
                .product(name: "PostgresKit", package: "postgres-wire"),
                .product(name: "SQLServerKit", package: "sqlserver-nio"),
            ]
        )
    ]
)
