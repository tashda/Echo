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
                .product(name: "HatchCore", package: "hatch"),
                .product(name: "HatchGit", package: "hatch"),
                .product(name: "HatchSync", package: "hatch"),
                .product(name: "HatchAgent", package: "hatch"),
                .product(name: "HatchAPI", package: "hatch"),
                .product(name: "HatchImport", package: "hatch"),
            ],
            path: "Sources/HatchApp"
        ),
    ],
    swiftLanguageModes: [.v5]
)
