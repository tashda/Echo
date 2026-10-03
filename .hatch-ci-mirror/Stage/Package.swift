// swift-tools-version: 6.0
// The Hatch Stage: the separate app in which the owner judges a Swift Proposal (decisions S1-S7, H1-H22).
//
// StageCore is pure Foundation and builds and tests on Linux. StageKit and the rounds need SwiftUI and AppKit, so they are only
// declared on macOS and `swift test` on Linux still works. The deployment target is macOS 26 (written as a string so a 6.0
// manifest can say it; a 6.2 manifest could use `.v26`).
import PackageDescription

var products: [Product] = [
    .library(name: "StageCore", targets: ["StageCore"]),
]

var targets: [Target] = [
    .target(name: "StageCore"),
    .testTarget(
        name: "StageCoreTests",
        dependencies: ["StageCore"],
        // The sample manifest of the toast round is decoded by a test, so it must exist next to the round.
        exclude: []
    ),
]

var dependencies: [Package.Dependency] = []

#if os(macOS)
dependencies.append(.package(path: ".."))

products.append(.library(name: "StageKit", targets: ["StageKit"]))
products.append(.executable(name: "HatchStageToast", targets: ["HatchStageToast"]))

targets.append(
    .target(
        name: "StageKit",
        dependencies: [
            "StageCore",
            // Only StageKit may depend on Hatch's local API (the adapter point is HatchAPIStageDataSource.swift).
            .product(name: "HatchAPI", package: "Hatch"),
        ]
    )
)
targets.append(
    // The spike round (decision O1): Echo today plus two options of the notification toast.
    // Plain SwiftUI, no EchoDesignSystem. `manifest.sample.json` is the manifest an agent would hand in with `hatch offer`.
    .executableTarget(
        name: "HatchStageToast",
        dependencies: ["StageKit", "StageCore"],
        path: "Sources/Rounds/ToastR18",
        exclude: ["manifest.sample.json"]
    )
)
#endif

let package = Package(
    name: "HatchStage",
    platforms: [.macOS("26.0")],
    products: products,
    dependencies: dependencies,
    targets: targets,
    swiftLanguageModes: [.v5]
)
