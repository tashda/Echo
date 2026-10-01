// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "EchoDesignSystem",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "EchoDesignSystem", targets: ["EchoDesignSystem"])
    ],
    targets: [
        .target(name: "EchoDesignSystem")
    ]
)
