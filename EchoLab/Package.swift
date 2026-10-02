// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "EchoLab",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../Packages/EchoDesignSystem"),
        .package(url: "https://github.com/tashda/echo-sense", branch: "dev"),
        .package(url: "https://github.com/tashda/echo-postgres", branch: "dev"),
        .package(url: "https://github.com/tashda/echo-sqlserver", branch: "dev"),
        .package(url: "https://github.com/tashda/echo-server-lab", branch: "dev")
    ],
    targets: [
        .executableTarget(
            name: "EchoLab",
            dependencies: [
                .product(name: "EchoDesignSystem", package: "EchoDesignSystem"),
                .product(name: "EchoSense", package: "echo-sense"),
                .product(name: "EchoSenseScenarios", package: "echo-sense"),
                .product(name: "PostgresKit", package: "echo-postgres"),
                .product(name: "SQLServerKit", package: "echo-sqlserver"),
                .product(name: "ServerLabCatalog", package: "echo-server-lab"),
                .product(name: "ServerLabWorkloads", package: "echo-server-lab"),
                .product(name: "TDSSpec", package: "echo-server-lab"),
            ]
        )
    ]
)
