// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "EchoLocalStorage",
    platforms: [.macOS(.v26)],
    products: [.library(name: "EchoLocalStorage", targets: ["EchoLocalStorage"])],
    targets: [.target(name: "EchoLocalStorage", linkerSettings: [.linkedLibrary("sqlite3")])]
)
