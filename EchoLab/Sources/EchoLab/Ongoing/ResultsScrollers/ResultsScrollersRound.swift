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
            .of("placement", "Horizontal scroll bar", LabRSPlacement.self, default: .bottomEdge,
                question: "Press Scroll in both exhibits a few times (or scroll them yourself), with 40 columns. Which bar belongs to the card, and does it ever crowd the footer's chips?",
                recommend: .bottomEdge,
                why: "The bottom edge is where a Mac puts a horizontal bar, it keeps the full width of the card, and the lane under the chips (9pt) is free, so it reads as part of the footer without touching it. C ties the bar to the chips' widths, so it shrinks to a stub in a narrow window; A is today's bar floating over the rows.",
                summary: \.summary),
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
                card(LabRSPlacement(rawValue: values["placement"]) ?? .bottomEdge, values)
            },
        ],
        questions: [
            .init(id: "everywhere", title: "Other grids", question: "Should the same placement apply to every grid that sits over a footer (the Messages console, Extended Events data), not only query results?",
                  choices: [.init(id: "all", name: "Every grid over a footer"), .init(id: "results", name: "Only query results")],
                  recommended: "all",
                  why: "They share the footer overlay (cardFooterOverlayHeight), so one rule keeps every card the same; only query results is a smaller change but leaves the others floating."),
        ],
        presets: [
            .init(id: "recommended", name: "Bottom edge", summary: "My recommendation.",
                  values: ["placement": LabRSPlacement.bottomEdge.rawValue, "columns": LabRSColumns.forty.rawValue], isRecommended: true),
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
