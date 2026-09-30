import Foundation
import SwiftUI

/// A frozen decision: what was asked, what won, why, and every option as live code.
/// Options are self-contained specimens with their values written out, so a decision looks
/// today exactly as it did when it was made, whatever the tokens do later.
@MainActor struct LabDecision: @MainActor Identifiable {
    let id: String
    /// Sidebar group, for example "Tabs" or "EchoSense".
    let area: String
    let title: String
    let symbol: String
    /// ISO date the owner confirmed it on the real app.
    let decidedOn: String
    let question: String
    /// Why it ended this way, including why the others lost.
    let reasoning: String
    /// Where it lives in Echo now: tokens, components, plan phase.
    let shipped: [String]
    /// The id of the decision that replaces this one, if any. Decisions are never edited.
    let supersededBy: String?
    let options: [LabDecisionOption]

    init(
        id: String,
        area: String,
        title: String,
        symbol: String,
        decidedOn: String,
        question: String,
        reasoning: String,
        shipped: [String] = [],
        supersededBy: String? = nil,
        options: [LabDecisionOption]
    ) {
        self.id = id
        self.area = area
        self.title = title
        self.symbol = symbol
        self.decidedOn = decidedOn
        self.question = question
        self.reasoning = reasoning
        self.shipped = shipped
        self.supersededBy = supersededBy
        self.options = options
    }

    var page: LabPage {
        LabPage(
            id: "decided.\(id)",
            section: .decided,
            group: area,
            title: title,
            symbol: symbol,
            status: .decided,
            summary: question
        ) { LabDecisionView(decision: self) }
    }
}

/// One option that was considered. `sourcePath` is the file holding its specimen, so the
/// library can show the code next to the rendering; pass `#filePath` from that file.
@MainActor struct LabDecisionOption: @MainActor Identifiable {
    let name: String
    let isWinner: Bool
    let why: String
    let sourcePath: String
    let specimen: () -> AnyView

    var id: String { name }

    init<Specimen: View>(
        name: String,
        isWinner: Bool = false,
        why: String,
        sourcePath: String = #filePath,
        @ViewBuilder specimen: @escaping () -> Specimen
    ) {
        self.name = name
        self.isWinner = isWinner
        self.why = why
        self.sourcePath = sourcePath
        self.specimen = { AnyView(specimen()) }
    }
}
