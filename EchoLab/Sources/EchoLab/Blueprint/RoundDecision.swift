import SwiftUI

/// How a round is decided: a list of topics, each a question with the choices you can pick.
/// The playground on the left is where you try things; this is where you say what you choose.
@MainActor
struct RoundDecision {
    struct Choice: Identifiable {
        let id: String
        let name: String
        var summary: String?
        /// The revision this choice was added in (2 or more), so it is marked New until reviewed.
        var addedIn: Int?
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
        /// The revision this whole topic was added in.
        var addedIn: Int?
        /// The choice currently selected in the playground, if this topic has a control there;
        /// it powers "Use what's selected in the preview".
        var preview: (@MainActor () -> String?)?
    }

    var topics: [Topic]

    /// The choices of an enum the playground already has (every case, named by its raw value).
    static func choices<E: CaseIterable & RawRepresentable>(_ type: E.Type, summary: ((E) -> String)? = nil,
                                                             added: (revision: Int, choices: [E])? = nil) -> [Choice]
    where E.RawValue == String {
        E.allCases.map { value in
            Choice(id: value.rawValue, name: value.rawValue, summary: summary?(value),
                   addedIn: added.flatMap { $0.choices.contains(where: { $0.rawValue == value.rawValue }) ? $0.revision : nil })
        }
    }
}

extension EnvironmentValues {
    /// True inside a round frame, where the frame draws the title, so playgrounds hide theirs.
    @Entry var labInRoundFrame = false
}
