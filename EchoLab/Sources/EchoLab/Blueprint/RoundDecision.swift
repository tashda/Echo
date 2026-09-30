import SwiftUI

/// How a round is decided: a list of topics, each a question with the choices you can pick.
/// The playground on the left is where you try things; this is where you say what you choose.
@MainActor
struct RoundDecision {
    struct Choice: Identifiable {
        let id: String
        let name: String
        var summary: String?
    }

    struct Topic: Identifiable {
        let id: String
        let title: String
        /// What to look at and decide.
        let question: String
        var choices: [Choice]
        /// The choice the agent recommends, and why. Every deciding topic has one.
        var recommended: String?
        var why: String?
        /// The choice currently selected in the playground, if this topic has a control there;
        /// it powers "Use what's selected in the preview".
        var preview: (@MainActor () -> String?)?
    }

    var topics: [Topic]

    /// The choices of an enum the playground already has (every case, named by its raw value).
    static func choices<E: CaseIterable & RawRepresentable>(_ type: E.Type, summary: ((E) -> String)? = nil) -> [Choice]
    where E.RawValue == String {
        E.allCases.map { Choice(id: $0.rawValue, name: $0.rawValue, summary: summary?($0)) }
    }
}

extension EnvironmentValues {
    /// True inside a round frame, where the frame draws the title, so playgrounds hide theirs.
    @Entry var labInRoundFrame = false
}
