import SwiftUI

/// Round 27 · Results scroll bars and the footer. Echo gives the grid's scroll view the footer's
/// room twice (content inset and scroller inset, which AppKit adds up), so the horizontal bar
/// floats over the rows a footer's height above the footer; the owner wants it to blend in. Changes
/// FTR-4.6 (the grid's scroll bars) next to FTR-2.1 and FTR-2.2.
@MainActor
enum ResultsScrollersRound {
    private static let width: CGFloat = 640
    private static let height: CGFloat = 400

    static let spec = RoundSpec(
        controls: [
            .of("placement", "Horizontal bar: where", LabRSPlacement.self, default: .ownLane,
                question: "Press Scroll both a few times (or scroll yourself) with 40 columns, and try each place. Which bar belongs to the card, and does it ever crowd the footer's chips?",
                recommend: .ownLane,
                why: "D keeps the bar where a Mac puts it, full width along the bottom, with a lane of its own, so it never meets a chip even when it widens under the pointer; the footer moves up by only that lane. B is the same without the lane; E still sits over the rows; F and G drop a scroll bar for something new; C shrinks to a stub in a narrow window; A is today.",
                summary: \.summary, newChoices: (2, LabRSPlacement.revision2)),
            .of("style", "Bar: how it looks", LabRSBarStyle.self, default: .system,
                question: "With your place picked, try each look. Does a styled bar feel like part of the card, or like something Echo made up?",
                recommend: .system,
                why: "The system's bar follows System Settings (Always show, sizes, Increase Contrast) and every other Mac app, so it is the one nobody has to learn; the place, not the paint, is what makes it fit. If you want it styled, S3 keeps the system's shape in the card's own colour, and S5 is the one that most belongs to the footer.",
                summary: \.summary, addedIn: 3),
            .of("visibility", "Bars: when they show", LabRSVisibility.self, default: .whileScrolling,
                question: "Move the pointer over the grid and to its bottom edge, and scroll. When should the bars be there?",
                recommend: .whileScrolling,
                why: "While scrolling is what macOS does and what System Settings can change to Always for whoever wants it; V3 is a good second, since the bar is there when you reach for it; V2 adds a permanent line to every grid.",
                summary: \.summary, addedIn: 3),
            .of("vertical", "Vertical bar: where it ends", LabRSVertical.self, default: .toBottom,
                question: "Scroll down. Should the vertical bar stop above the footer, run down to the horizontal bar, or go?",
                recommend: .toBottom,
                why: "Running down to the horizontal bar frames the rows on two sides and uses the same lane the horizontal bar has; stopping above the footer leaves a gap beside the pills, and the row numbers alone are a weak position for long results.",
                summary: \.summary, addedIn: 3),
            .of("extra", "Tie the position to the card", LabRSExtra.self, default: .edgeFades,
                question: "Scroll sideways to the middle and to each end. Does anything besides the bar help you know there is more to the side?",
                recommend: .edgeFades,
                why: "Soft edges say there is more without adding a control, they match the footer's blur at the bottom, and they work with any bar or none; X2 and X4 repeat what the bar says; X3 is lovely with many columns but crowds the footer.",
                summary: \.summary, addedIn: 3),
            .of("columns", "Columns", LabRSColumns.self, default: .forty),
        ],
        actions: [
            .init(id: "scroll", title: "Scroll both", symbol: "arrow.down.right") { $0["scrollToken"] = UUID().uuidString },
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Bar floating a footer's height above the footer, system style, shown while scrolling, nothing else.",
                  isEchoToday: true, designWidth: width, designHeight: height) { values in
                card(.today, values, drawsBars: false)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls on the left.",
                  designWidth: width, designHeight: height) { values in
                card(options(values), values)
            },
        ],
        questions: [
            .init(id: "everywhere", title: "Other grids", question: "Should the same choice apply to every grid that sits over a footer (the Messages console, Extended Events data), not only query results?",
                  choices: [.init(id: "all", name: "Every grid over a footer"), .init(id: "results", name: "Only query results"),
                            .init(id: "everything", name: "Every scroll bar in a card", summary: "Grids, the editor, the Activity Monitor and tool tabs, footer or not: the horizontal bar always sits the same way at the card's bottom.", addedIn: 2),
                            .init(id: "gridsEditor", name: "Everything under the footer", summary: "The grids and the SQL editor, which also scroll under the footer today.", addedIn: 2),
                            .init(id: "resultsData", name: "Query results and table data", summary: "The two grids of rows you browse; the Messages console and Extended Events keep today's bar.", addedIn: 2)],
                  recommended: "everything",
                  why: "One rule for every card makes the bar a piece of the card, not of the footer: cards without a footer already have their bar at the bottom edge, so this mostly brings the footer cards in line. Everything under the footer is the next best: the editor matches the grid it sits on."),
        ],
        presets: [
            .init(id: "recommended", name: "Native, in its own lane", summary: "My recommendation: D, S1, V1, R2, X1.",
                  values: values(.ownLane, .system, .whileScrolling, .toBottom, .edgeFades), isRecommended: true),
            .init(id: "today", name: "As today", summary: "A, S1, V1, R1, X0.",
                  values: values(.aboveFooter, .system, .whileScrolling, .aboveFooter, .none)),
            .init(id: "card", name: "In the card's colours", summary: "D, S3, V3, R2, X1: the system's shape in the card's tint, there when you reach for it.",
                  values: values(.ownLane, .softCapsule, .nearBottom, .toBottom, .edgeFades)),
            .init(id: "glass", name: "Glass, like the footer", summary: "B, S5, V4, R2, X2: a glass track with the footer's chips, while the pointer is over the grid.",
                  values: values(.bottomEdge, .glass, .overGrid, .toBottom, .footerLine)),
            .init(id: "footerLed", name: "The footer is the bar", summary: "F, S2, V1, R2, X1: a glass track in the footer, a thin vertical line.",
                  values: values(.glassTrack, .thinLine, .whileScrolling, .toBottom, .edgeFades)),
            .init(id: "minimal", name: "Almost nothing", summary: "G, S2, V1, R3, X1: a position chip and soft edges, no bars.",
                  values: values(.positionChip, .thinLine, .whileScrolling, .hidden, .edgeFades)),
            .init(id: "map", name: "Column map", summary: "D, S2, V3, R2, X3: a thin line and a map of the columns in the footer.",
                  values: values(.ownLane, .thinLine, .nearBottom, .toBottom, .columnMap)),
        ]
    )

    private static func values(_ placement: LabRSPlacement, _ style: LabRSBarStyle, _ visibility: LabRSVisibility,
                               _ vertical: LabRSVertical, _ extra: LabRSExtra) -> [String: String] {
        ["placement": placement.rawValue, "style": style.rawValue, "visibility": visibility.rawValue,
         "vertical": vertical.rawValue, "extra": extra.rawValue, "columns": LabRSColumns.forty.rawValue]
    }

    private static func options(_ values: RoundValues) -> LabRSOptionSet {
        LabRSOptionSet(placement: LabRSPlacement(rawValue: values["placement"]) ?? .ownLane,
                       style: LabRSBarStyle(rawValue: values["style"]) ?? .system,
                       visibility: LabRSVisibility(rawValue: values["visibility"]) ?? .whileScrolling,
                       vertical: LabRSVertical(rawValue: values["vertical"]) ?? .toBottom,
                       extra: LabRSExtra(rawValue: values["extra"]) ?? .edgeFades)
    }

    private static func card(_ options: LabRSOptionSet, _ values: RoundValues, drawsBars: Bool = true) -> some View {
        LabRSCard(options: options, drawsBars: drawsBars,
                  columnCount: (LabRSColumns(rawValue: values["columns"]) ?? .forty).count,
                  scrollToken: values["scrollToken"])
    }
}
