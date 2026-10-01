import SwiftUI

/// Round 27 · Results scroll bars and the footer, accepted 2026-10-01 and built into Echo: E (on
/// the footer's top edge, the thumb as far above the pills as the pills sit above the card's
/// edge), S1 (the system's bar), V1 (while scrolling), R2 (the vertical bar down to it), X1 (soft
/// edges where more columns wait), for every scroll bar over a footer. Trimmed to that choice;
/// the other options (A to G, S2 to S6, V2 to V4, R1 and R3, X2 to X4) are in its history. FTR-4.6.
@MainActor
enum ResultsScrollersRound {
    private static let width: CGFloat = 640
    private static let height: CGFloat = 400

    static let spec = RoundSpec(
        controls: [
            .of("columns", "Columns", LabRSColumns.self, default: .forty),
        ],
        actions: [
            .init(id: "scroll", title: "Scroll both", symbol: "arrow.down.right") { $0["scrollToken"] = UUID().uuidString },
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "As built: the system's bar on the footer's top edge, 9pt above the pills, shown while scrolling; the vertical bar down to it; soft edges where more columns wait.",
                  isEchoToday: true, designWidth: width, designHeight: height) { values in
                card(.decided, values)
            },
            .init(id: "before", title: "Before", summary: "Echo before round 27: the bar floated a footer's height above the footer (the footer's room was set twice).",
                  designWidth: width, designHeight: height) { values in
                card(.before, values, drawsBars: false)
            },
        ]
    )

    private static func card(_ options: LabRSOptionSet, _ values: RoundValues, drawsBars: Bool = true) -> some View {
        LabRSCard(options: options, drawsBars: drawsBars,
                  columnCount: (LabRSColumns(rawValue: values["columns"]) ?? .forty).count,
                  scrollToken: values["scrollToken"])
    }
}
