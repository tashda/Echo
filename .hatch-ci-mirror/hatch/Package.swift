// swift-tools-version: 6.0
// Hatch core: everything that is not user interface. Builds on macOS and Linux.
// The SwiftUI app and the Stage live in separate packages (HatchApp/, HatchStage/) and only build on macOS.
import PackageDescription

let package = Package(
    name: "Hatch",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "HatchCore", targets: ["HatchCore"]),
        .library(name: "HatchGit", targets: ["HatchGit"]),
        .library(name: "HatchSync", targets: ["HatchSync"]),
        .library(name: "HatchAgent", targets: ["HatchAgent"]),
        .library(name: "HatchAPI", targets: ["HatchAPI"]),
        .library(name: "HatchImport", targets: ["HatchImport"]),
        .executable(name: "hatch", targets: ["hatch"]),
    ],
    targets: [
        .systemLibrary(name: "CSQLite", pkgConfig: "sqlite3", providers: [.apt(["libsqlite3-dev"]), .brew(["sqlite"])]),
        .target(name: "HatchCore", dependencies: [.target(name: "CSQLite", condition: .when(platforms: [.linux]))]),
        .target(name: "HatchGit", dependencies: ["HatchCore"]),
        .target(name: "HatchSync", dependencies: ["HatchCore"]),
        .target(name: "HatchAgent", dependencies: ["HatchCore"]),
        .target(name: "HatchAPI", dependencies: ["HatchCore"]),
        .target(name: "HatchImport", dependencies: ["HatchCore"]),
        .executableTarget(name: "hatch", dependencies: ["HatchCore", "HatchGit", "HatchSync", "HatchAgent", "HatchAPI", "HatchImport"]),
        .testTarget(name: "HatchCoreTests", dependencies: ["HatchCore"]),
        .testTarget(name: "HatchGitTests", dependencies: ["HatchGit", "HatchCore"]),
        .testTarget(name: "HatchSyncTests", dependencies: ["HatchSync", "HatchCore"]),
        .testTarget(name: "HatchAgentTests", dependencies: ["HatchAgent", "HatchCore"]),
        .testTarget(name: "HatchAPITests", dependencies: ["HatchAPI", "HatchCore"]),
        .testTarget(name: "HatchImportTests", dependencies: ["HatchImport", "HatchCore"]),
    ],
    swiftLanguageModes: [.v5]
)
