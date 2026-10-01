import SwiftUI

/// Round 26 · Tab content while the tree slides. Changes WIN-3.2 (hide and show) and the
/// inspector's slide, which works the same way. Traced 2026-10-01: over a query tab the slide runs
/// at 60 fps; over the Activity Monitor at about 20 fps, because every cell of its SwiftUI tables
/// lays out again on every frame as the card's width changes.
@MainActor
enum ContentDuringSlideRound {
    private static let width: CGFloat = 700
    private static let height: CGFloat = 420

    static let spec = RoundSpec(
        controls: [
            .of("mode", "While the card slides", LabCDSMode.self, default: .holdThenSettle,
                question: "Press Hide or Show Tree in both exhibits a few times, with 400 rows. Which slide is smooth, and is the content's one change of width acceptable where it happens?",
                recommend: .holdThenSettle,
                why: "The slide itself becomes as smooth as over a query tab, and the columns change once, after the motion, when the eye has settled. C also slides smoothly but jumps the columns at the very moment you act, which reads as a glitch; A is today's 20 fps.",
                summary: \.summary),
            .of("rows", "Table", LabCDSRows.self, default: .many),
            .of("speed", "Speed", LabSpeed.self, default: .standard),
        ],
        actions: [
            .init(id: "toggle", title: "Hide or Show Tree in both", symbol: "sidebar.left") { $0["toggleToken"] = UUID().uuidString },
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: LabCDSMode.live.summary,
                  isEchoToday: true, designWidth: width, designHeight: height) { values in
                window(.live, values)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the control above.",
                  designWidth: width, designHeight: height) { values in
                window(LabCDSMode(rawValue: values["mode"]) ?? .holdThenSettle, values)
            },
        ],
        questions: [
            .init(id: "scope", title: "Where it applies", question: "Should the chosen behaviour apply to every tab, or only to tabs with tables (Activity Monitor, tool tabs)?",
                  choices: [.init(id: "all", name: "Every tab"), .init(id: "tables", name: "Only tabs with tables")],
                  recommended: "all",
                  why: "One rule for the whole window keeps the slide the same everywhere; query tabs are already smooth, and holding their width costs nothing."),
        ],
        presets: [
            .init(id: "recommended", name: "Hold, settle at the end", summary: "My recommendation.",
                  values: ["mode": LabCDSMode.holdThenSettle.rawValue, "rows": LabCDSRows.many.rawValue], isRecommended: true),
            .init(id: "today", name: "As today", summary: "Reflow on every frame.",
                  values: ["mode": LabCDSMode.live.rawValue, "rows": LabCDSRows.many.rawValue]),
        ]
    )

    private static func window(_ mode: LabCDSMode, _ values: RoundValues) -> some View {
        LabCDSWindow(mode: mode, rows: (LabCDSRows(rawValue: values["rows"]) ?? .many).count,
                     speed: LabSpeed(rawValue: values["speed"]) ?? .standard,
                     toggleToken: values["toggleToken"])
    }
}
