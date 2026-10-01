import SwiftUI

/// The blueprint every "As built" page fills in. A page says what Echo looks like and does today
/// in seven fixed parts, so every area reads the same way: See it, How it behaves, How it moves,
/// Measurements, Why it looks this way, In the code, and how far it has been checked.
@MainActor
struct AsBuiltPage {
    /// How far the page has been checked against Echo.
    struct Verification {
        enum Level { case runningApp, code }
        let level: Level
        let commit: String
        let date: String
        var note: String?
    }

    struct Behaviour: Identifiable {
        let trigger: String
        let result: String
        var id: String { trigger }
    }

    struct Motion: Identifiable {
        let name: String
        /// For example "spring, bounce 0.08" or "ease in-out".
        let curve: String
        let duration: String
        var note: String?
        var id: String { name }
    }

    struct Measurement: Identifiable {
        let label: String
        let value: String
        /// The token or constant that holds the value in code.
        var token: String?
        /// Something to double-check, shown as a quiet warning.
        var check: String?
        var id: String { label }
    }

    struct Rule: Identifiable {
        let text: String
        let why: String
        /// Round pages (`LabPage.id`) that decided it, shown as links.
        var rounds: [String] = []
        var id: String { text }
    }

    var verification: Verification?
    /// Height of the stage the specimen sits on.
    var stageHeight: CGFloat = 520
    var specimen: () -> AnyView
    /// Controls that belong to this specimen, shown under the stage.
    var controls: (() -> AnyView)?
    var behaviours: [Behaviour] = []
    var motions: [Motion] = []
    var measurements: [Measurement] = []
    var rules: [Rule] = []
    var code: [String] = []

    init<Specimen: View>(
        verification: Verification? = nil,
        stageHeight: CGFloat = 520,
        behaviours: [Behaviour] = [],
        motions: [Motion] = [],
        measurements: [Measurement] = [],
        rules: [Rule] = [],
        code: [String] = [],
        @ViewBuilder specimen: @escaping () -> Specimen
    ) {
        self.verification = verification
        self.stageHeight = stageHeight
        self.behaviours = behaviours
        self.motions = motions
        self.measurements = measurements
        self.rules = rules
        self.code = code
        self.specimen = { AnyView(specimen()) }
    }

    /// Adds specimen-specific controls under the stage.
    func controls<Controls: View>(@ViewBuilder _ controls: @escaping () -> Controls) -> AsBuiltPage {
        var copy = self
        copy.controls = { AnyView(controls()) }
        return copy
    }

    /// A placeholder until an area's page is written; the area's rounds are still available.
    static func pending(_ area: String) -> AsBuiltPage {
        AsBuiltPage(stageHeight: 220) {
            ContentUnavailableView(
                "The As built page for \(area) is not written yet",
                systemImage: "doc.badge.clock",
                description: Text("Its rounds are under Rounds. This page will show how it looks, behaves and moves today."))
        }
    }
}
