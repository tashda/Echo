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

    /// For playgrounds whose questions were written as `DesignLabPage.questions`.
    static func legacy(_ page: DesignLabPage) -> RoundDecision {
        RoundDecision(topics: page.questions.map { question in
            let advice = legacyAdvice[question.id]
            return Topic(id: question.id, title: question.title, question: question.howTo,
                         choices: question.options.map { Choice(id: $0, name: $0) },
                         recommended: advice?.choice, why: advice?.why)
        })
    }

    /// Recommendations for the pages that have not been rewritten as a `RoundSpec` yet. Where
    /// you have already answered on the design board, the recommendation is that answer.
    private static let legacyAdvice: [String: (choice: String, why: String)] = [
        "round14-bar-style": (LabRound14BarStyle.today.rawValue, "You chose Round 9's strip on one line; N1R and N7 were rejected."),
        "round14-page-style": (LabRound14PageStyle.unfold.rawValue, "You chose ST2: the tool's tab unfolds and shows its pages inside itself."),
        "round14-cn5": ("Accept", "You chose CN5: edit a connection inside Manage Connections, with CN2's short sheet."),
        "round14-esr4": (LabSenseSelection.tintThenSolid.rawValue, "Tint while typing, solid once you use the arrows, so the solid state tells you Return inserts it."),
        "round14-esr5": (LabSenseCorners.followCards.rawValue, "The popup should look like the other cards and follow Card Corners, capped so rows stay concentric."),
        "round15-run": ("1", "The quiet glyph keeps Run a plain ▶ like its neighbours, so changing it moves nothing else in the toolbar."),
        "round15-inspector": (LabInspectorLook.groupedBoxes.rawValue, "One card avoids the stacked, cut-off shadows, and inset groups read like System Settings."),
        "round15-history": ("B", "The history takes the inspector's column: room for long messages, and the same card and boxes as the inspector."),
        "round15-toast-top": (LabToastTop.belowTabBar.rawValue, "Toasts sit inside the tab's first card, below the tab bar, so they never cover the toolbar."),
    ]
}

extension EnvironmentValues {
    /// True inside a round frame, where the frame draws the title, so playgrounds hide theirs.
    @Entry var labInRoundFrame = false
}
