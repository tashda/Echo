// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "EchoLab",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../Packages/EchoDesignSystem"),
        .package(url: "https://github.com/tashda/EchoSense", branch: "dev"),
        .package(url: "https://github.com/tashda/postgres-wire", branch: "dev"),
        .package(url: "https://github.com/tashda/sqlserver-nio", branch: "dev"),
        .package(url: "https://github.com/tashda/echo-server-lab", branch: "dev")
    ],
    targets: [
        .executableTarget(
            name: "EchoLab",
            dependencies: [
                .product(name: "EchoDesignSystem", package: "EchoDesignSystem"),
                .product(name: "EchoSense", package: "EchoSense"),
                .product(name: "EchoSenseScenarios", package: "EchoSense"),
                .product(name: "PostgresKit", package: "postgres-wire"),
                .product(name: "SQLServerKit", package: "sqlserver-nio"),
                .product(name: "ServerLabCatalog", package: "echo-server-lab"),
                .product(name: "TDSSpec", package: "echo-server-lab"),
            ]
        )
    ]
)
