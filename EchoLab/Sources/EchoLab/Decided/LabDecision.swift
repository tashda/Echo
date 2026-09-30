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

/// One option that was considered. `sourceFiles` are the files holding its specimen, so the
/// library can show the code next to the rendering; they are looked up next to the file that
/// declares the option (pass nothing for `directory`, it defaults to the caller's `#filePath`).
@MainActor
struct LabDecisionOption: @MainActor Identifiable {
    let name: String
    let isWinner: Bool
    let why: String
    let sourcePaths: [String]
    let specimen: () -> AnyView

    var id: String { name }

    init<Specimen: View>(
        name: String,
        isWinner: Bool = false,
        why: String,
        sourceFiles: [String] = [],
        directory: String = #filePath,
        @ViewBuilder specimen: @escaping () -> Specimen
    ) {
        self.name = name
        self.isWinner = isWinner
        self.why = why
        let folder = URL(fileURLWithPath: directory).deletingLastPathComponent()
        self.sourcePaths = sourceFiles.map { folder.appending(path: $0).path }
        self.specimen = { AnyView(specimen()) }
    }
}
