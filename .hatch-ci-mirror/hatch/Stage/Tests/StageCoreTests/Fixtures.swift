import Foundation
@testable import StageCore

enum Fixtures {
    static var packageRoot: URL {
        // .../Stage/Tests/StageCoreTests/Fixtures.swift
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    static var sampleManifestURL: URL {
        packageRoot.appendingPathComponent("Sources/Rounds/ToastR18/manifest.sample.json")
    }

    static func sampleManifestText() throws -> String {
        try String(contentsOf: sampleManifestURL, encoding: .utf8)
    }

    static func toast() throws -> StageManifest {
        try StageManifest.parse(json: try sampleManifestText())
    }

    /// Three options so the filmstrip rule can be tested.
    static func fiveOptions() -> StageManifest {
        var m = StageManifest(revision: 1)
        m.specimens = [StageSpecimen(id: "t", title: "Echo today", isEchoToday: true)]
        for k in ["a", "b", "c", "d", "e"] { m.specimens.append(StageSpecimen(id: k, title: "Option \(k.uppercased())")) }
        m.controls = [StageControl(id: "pad", title: "Padding", choices: [StageChoice(id: "12", name: "12"), StageChoice(id: "16", name: "16")],
                                   defaultChoice: "12", question: "Which?", recommend: "16", why: "Because.")]
        m.exhibitTopic = StageTopic(id: "which", title: "Which?", question: "Pick.", recommended: "c", why: "Best.")
        return m
    }

    static func state(for m: StageManifest) -> StageState { StageState(manifest: m) }
}
