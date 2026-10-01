import SwiftUI

/// Round 27 · Results scroll bars and the footer. Echo sets the grid's scroller insets to the
/// footer's height (ResultTableContainerView.setFooterOverlay), so the horizontal bar floats over
/// the last rows above the footer; the owner finds it in the wrong place and wants it to blend in
/// with the footer. Changes FTR-4.6 (the grid's scroll bars) next to FTR-2.1 and FTR-2.2.
@MainActor
enum ResultsScrollersRound {
    private static let width: CGFloat = 640
    private static let height: CGFloat = 400

    static let spec = RoundSpec(
        controls: [
            .of("placement", "Horizontal scroll bar", LabRSPlacement.self, default: .ownLane,
                question: "Press Scroll in both exhibits a few times (or scroll them yourself), with 40 columns, and try each option. Which bar belongs to the card, and does it ever crowd the footer's chips? D to G are new.",
                recommend: .ownLane,
                why: "D keeps the system bar where a Mac puts it, full width along the bottom, and gives it a lane of its own, so it never meets a chip even when it widens under the pointer; the footer moves up by only that lane. B is the same without the lane (it can touch the chips when it widens); E still sits over the rows; F and G replace a system control with our own, which loses the click-to-page and the widening thumb; C shrinks to a stub in a narrow window; A is today.",
                summary: \.summary, newChoices: (2, LabRSPlacement.revision2)),
            .of("columns", "Columns", LabRSColumns.self, default: .forty),
        ],
        actions: [
            .init(id: "scroll", title: "Scroll both", symbol: "arrow.down.right") { $0["scrollToken"] = UUID().uuidString },
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: LabRSPlacement.aboveFooter.summary,
                  isEchoToday: true, designWidth: width, designHeight: height) { values in
                card(.aboveFooter, values)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the control above.",
                  designWidth: width, designHeight: height) { values in
                card(LabRSPlacement(rawValue: values["placement"]) ?? .ownLane, values)
            },
        ],
        questions: [
            .init(id: "everywhere", title: "Other grids", question: "Should the same placement apply to every grid that sits over a footer (the Messages console, Extended Events data), not only query results?",
                  choices: [.init(id: "all", name: "Every grid over a footer"), .init(id: "results", name: "Only query results"),
                            .init(id: "everything", name: "Every scroll bar in a card", summary: "Grids, the editor, the Activity Monitor and tool tabs, footer or not: the horizontal bar always sits the same way at the card's bottom.", addedIn: 2),
                            .init(id: "gridsEditor", name: "Everything under the footer", summary: "The grids and the SQL editor, which also scroll under the footer today.", addedIn: 2),
                            .init(id: "resultsData", name: "Query results and table data", summary: "The two grids of rows you browse; the Messages console and Extended Events keep today's bar.", addedIn: 2)],
                  recommended: "everything",
                  why: "One rule for every card makes the bar a piece of the card, not of the footer: cards without a footer already have their bar at the bottom edge, so this mostly brings the footer cards in line. Everything under the footer is the next best: the editor matches the grid it sits on."),
        ],
        presets: [
            .init(id: "recommended", name: "Its own lane", summary: "My recommendation.",
                  values: ["placement": LabRSPlacement.ownLane.rawValue, "columns": LabRSColumns.forty.rawValue], isRecommended: true),
            .init(id: "bottomEdge", name: "Bottom edge", summary: "The first recommendation.",
                  values: ["placement": LabRSPlacement.bottomEdge.rawValue, "columns": LabRSColumns.forty.rawValue]),
            .init(id: "today", name: "As today", summary: "Floating above the footer.",
                  values: ["placement": LabRSPlacement.aboveFooter.rawValue, "columns": LabRSColumns.forty.rawValue]),
        ]
    )

    private static func card(_ placement: LabRSPlacement, _ values: RoundValues) -> some View {
        LabRSCard(placement: placement,
                  columnCount: (LabRSColumns(rawValue: values["columns"]) ?? .forty).count,
                  scrollToken: values["scrollToken"])
    }
}
