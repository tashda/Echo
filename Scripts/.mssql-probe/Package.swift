// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MSSQLProbe",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "mssql-probe", targets: ["MSSQLProbe"])
    ],
    dependencies: [
        .package(path: "/Users/k/Development/tds-nio")
    ],
    targets: [
        .executableTarget(
            name: "MSSQLProbe",
            dependencies: [
                .product(name: "TDS", package: "tds-nio")
            ]
        )
    ]
)
