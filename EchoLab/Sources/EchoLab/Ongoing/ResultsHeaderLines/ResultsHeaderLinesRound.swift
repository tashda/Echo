import SwiftUI

/// Round 41.1 · Results: the column header's lines. Measured in the owner's screenshot (2x): a 1pt
/// line under the header (229) and a 0.5pt line about 4pt below it (230). ResultTableHeaderView.draw
/// fills a full-width `separatorColor` rect "because the native header doesn't always draw it", and
/// the system's own header separator is still drawn. Changes FTR (results grid header).
///
/// Accepted 2026-10-01: HL1 and VD0. Built into Echo: ResultTableHeaderView no longer draws its own
/// line (FTR-4.2).
@MainActor
enum ResultsHeaderLinesRound {
    enum Rule: String, CaseIterable {
        case today = "HL0 · Two lines, 4pt apart (today)"
        case system = "HL1 · One hairline: the system header's own"
        case echo = "HL2 · One 1pt line: Echo's, with the system's turned off"
        case soft = "HL3 · No line; a soft shade under the header while rows scroll beneath"

        var rule: LabWKGrid.HeaderRule {
            switch self {
            case .today: .doubled
            case .system: .single
            case .echo: .thick
            case .soft: .soft
            }
        }
    }

    static let spec = RoundSpec(
        controls: [
            .of("rule", "Under the header", Rule.self, default: .system,
                question: "Compare the line under the column names. Which looks right?",
                recommend: .system,
                why: "A single hairline is how every macOS table separates its header (Finder, Mail, Xcode). The custom line was added for a case where the system didn't draw one; that case should be fixed where it happens instead of drawing a second line everywhere. HL3 matches the tree's pinned header, but a grid needs a firm edge to read columns against."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Two lines under the header.", isEchoToday: true, designWidth: 600, designHeight: 240) { _ in
                LabRHGrid(rule: .doubled)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls.", designWidth: 600, designHeight: 240) { values in
                LabRHGrid(rule: (Rule(rawValue: values["rule"]) ?? .system).rule)
            },
        ],
        questions: [
            .init(id: "verticals", title: "Column dividers",
                  question: "The header has short vertical dividers between columns. Keep them?",
                  choices: [.init(id: "keep", name: "VD0 · Keep: they mark where to drag a column's width"), .init(id: "hover", name: "VD1 · Only while the pointer is over the header")],
                  recommended: "keep",
                  why: "They are the resize handles; hiding them makes a grid of 15 columns hard to resize."),
        ],
        presets: [.init(id: "recommended", name: "My recommendation", values: ["rule": Rule.system.rawValue], isRecommended: true)]
    )
}

private struct LabRHGrid: View {
    let rule: LabWKGrid.HeaderRule
    var body: some View {
        VStack(spacing: SpacingTokens.none) {
            LabWKGrid(columns: [.init(name: "bagno", type: "char"), .init(name: "histDate", type: "char"), .init(name: "Centre", type: "char", width: 90),
                                .init(name: "uniqueBagID", type: "char", width: 140)],
                      rows: [["10385498", "", "10", "2610000125260"], ["230166744027", "", "10", ""], ["230174723054", "", "10", ""], ["230186043605", "", "10", ""]],
                      headerRule: rule)
            Spacer(minLength: 0)
        }
        .workspaceCard()
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Workspace.canvas)
    }
}
