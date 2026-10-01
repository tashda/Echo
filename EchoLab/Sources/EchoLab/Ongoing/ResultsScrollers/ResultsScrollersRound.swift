import SwiftUI

/// Round 27 · Results scroll bars and the footer, built into Echo. Accepted 2026-10-01 (E, S1,
/// V1, R2, X1, with the thumb as far above the pills as the pills sit above the edge), then
/// refined in revision 5 and accepted again: L2 (as wide as the footer), U5 (the blur rises past
/// the bar while it shows, animated, with a softer edge), H1 and T1. The owner then asked for the
/// same blur behind every horizontal bar in the app (ScrollBarBlur). Trimmed to that choice; the
/// other options are in the round's history. FTR-4.6.
@MainActor
enum ResultsScrollersRound {
    private static let width: CGFloat = 640
    private static let height: CGFloat = 400

    static let spec = RoundSpec(
        controls: [
            .of("hold", "Bars", LabRSHold.self, default: .whileScrolling),
            .of("columns", "Columns", LabRSColumns.self, default: .forty),
        ],
        actions: [
            .init(id: "scroll", title: "Scroll both", symbol: "arrow.down.right") { $0["scrollToken"] = UUID().uuidString },
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "As built: the system's bar on the footer's top edge, 9pt above the pills, as wide as the footer; while it shows the blur rises past it and settles after; the vertical bar down to it; soft side edges.",
                  isEchoToday: true, designWidth: width, designHeight: height) { values in
                card(held(.decided, values), values)
            },
            .init(id: "before", title: "Before", summary: "Echo before round 27: the bar floated a footer's height above the footer (the footer's room was set twice).",
                  designWidth: width, designHeight: height) { values in
                card(held(.before, values), values, drawsBars: false)
            },
        ]
    )

    private static func held(_ options: LabRSOptionSet, _ values: RoundValues) -> LabRSOptionSet {
        var options = options
        options.holdsBars = LabRSHold(rawValue: values["hold"]) == .keep
        return options
    }

    private static func card(_ options: LabRSOptionSet, _ values: RoundValues, drawsBars: Bool = true) -> some View {
        LabRSCard(options: options, drawsBars: drawsBars,
                  columnCount: (LabRSColumns(rawValue: values["columns"]) ?? .forty).count,
                  scrollToken: values["scrollToken"])
    }
}
