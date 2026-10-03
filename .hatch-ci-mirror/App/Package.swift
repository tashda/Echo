// swift-tools-version: 6.2
// The Hatch macOS app. macOS only (SwiftUI, AppKit, WebKit). Core logic lives in the parent package.
import PackageDescription

let package = Package(
    name: "HatchApp",
    platforms: [.macOS(.v26)],
    products: [.executable(name: "HatchApp", targets: ["HatchApp"])],
    dependencies: [.package(path: "..")],
    targets: [
        .executableTarget(
            name: "HatchApp",
            dependencies: [
                .product(name: "HatchCore", package: "Hatch"),
                .product(name: "HatchGit", package: "Hatch"),
                .product(name: "HatchSync", package: "Hatch"),
                .product(name: "HatchAgent", package: "Hatch"),
                .product(name: "HatchAPI", package: "Hatch"),
                .product(name: "HatchImport", package: "Hatch"),
            ],
            path: "Sources/HatchApp"
        ),
    ],
    swiftLanguageModes: [.v5]
)
