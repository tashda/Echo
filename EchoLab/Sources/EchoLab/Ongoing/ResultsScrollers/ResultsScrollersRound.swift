import SwiftUI

/// Round 27 · Results scroll bars and the footer. Accepted 2026-10-01 and built (E, S1, V1, R2, X1,
/// with the bar's thumb as far above the pills as the pills sit above the edge). The owner loves
/// it "about 90%": it doesn't reach as far as the footer, and it isn't on the blur. Revision 5
/// refines what is built: its length, what is behind it, its gap to the pills and its track. The
/// options not chosen the first time (A to G, S2 to S6, V2 to V4, R1, R3, X2 to X4) are in the
/// round's history. FTR-4.6.
@MainActor
enum ResultsScrollersRound {
    private static let width: CGFloat = 640
    private static let height: CGFloat = 400

    static let spec = RoundSpec(
        controls: [
            .of("length", "How far it reaches", LabRSLength.self, default: .footer,
                question: "Press Keep them visible (or scroll), then compare the bar's ends with the footer's chip and last pill. Should it reach as far as the footer?",
                recommend: .footer,
                why: "Its ends then line up with the chip and the last pill, so bar and footer read as one block; it costs a little truth, since the row numbers don't scroll sideways. As built it starts after the row numbers, later than the footer, which is the 'doesn't stretch out as far' you see.",
                summary: \.summary, addedIn: 5),
            .of("behind", "What is behind it", LabRSBehind.self, default: .blurUp,
                question: "Look at the rows right behind the bar. Should the bar sit on sharp rows, on the footer's blur, on glass, or on the card?",
                recommend: .blurUp,
                why: "The blur reaching just past the bar makes the bar part of the footer's zone, the same soft ground the pills stand on, with nothing new drawn. It softens 16pt more of the last rows; U5 avoids that by growing the blur only while you scroll, at the cost of the blur moving. A glass lane (U3) is a second glass object beside the pills; the soft band (U4) hides rows rather than softening them.",
                summary: \.summary, addedIn: 5),
            .of("gap", "Gap to the pills", LabRSGap.self, default: .built,
                question: "With your pick above, is 9pt still right, or should the bar sit closer to the pills or further away?",
                recommend: .built,
                why: "Your note set it: the gap the pills keep above the card's edge, so the footer's spacing repeats once more. Snug makes bar and pills one block but crowds the chip's glass; roomier lets the bar drift back toward the rows.",
                summary: \.summary, addedIn: 5),
            .of("track", "Its track", LabRSTrack.self, default: .faint,
                question: "Scroll sideways. Does a faint track along the bar's length help you see how far it reaches and where you are?",
                recommend: .faint,
                why: "With the bar as wide as the footer, its track shows that width while you scroll, so the bar reads as the footer's edge rather than a short thumb floating in it. The system bar shows its track only under the pointer; this is the one place we'd draw it sooner.",
                summary: \.summary, addedIn: 5),
            .of("hold", "Bars", LabRSHold.self, default: .whileScrolling),
            .of("columns", "Columns", LabRSColumns.self, default: .forty),
        ],
        actions: [
            .init(id: "scroll", title: "Scroll both", symbol: "arrow.down.right") { $0["scrollToken"] = UUID().uuidString },
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "As built: the system's bar on the footer's top edge, 9pt above the pills, from the row numbers to the right side, over sharp rows; soft side edges.",
                  isEchoToday: true, designWidth: width, designHeight: height) { values in
                card(held(.decided, values), values)
            },
            .init(id: "proposal", title: "Proposal", summary: "Echo today with the four choices on the left.",
                  addedIn: 5, designWidth: width, designHeight: height) { values in
                card(refined(values), values)
            },
            .init(id: "before", title: "Before", summary: "Echo before round 27: the bar floated a footer's height above the footer (the footer's room was set twice).",
                  designWidth: width, designHeight: height) { values in
                card(held(.before, values), values, drawsBars: false)
            },
        ],
        presets: [
            .init(id: "recommended", name: "One block with the footer", summary: "My recommendation: L2, U2, H1, T2.",
                  values: values(.footer, .blurUp, .built, .faint), isRecommended: true),
            .init(id: "built", name: "As built", summary: "L1, U1, H1, T1.",
                  values: values(.grid, .sharp, .built, .none)),
            .init(id: "onDemand", name: "Blur when it shows", summary: "L2, U5, H1, T2: the blur rises past the bar only while you scroll.",
                  values: values(.footer, .blurOnDemand, .built, .faint)),
            .init(id: "glass", name: "A glass lane", summary: "L2, U3, H1, T1: the bar in a slim glass capsule, like the pills.",
                  values: values(.footer, .glassLane, .built, .none)),
            .init(id: "band", name: "On the card", summary: "L2, U4, H1, T1: a band of the card's colour behind the bar.",
                  values: values(.footer, .softBand, .built, .none)),
            .init(id: "snug", name: "Snug", summary: "L2, U2, H2, T1: closer to the pills, one block.",
                  values: values(.footer, .blurUp, .snug, .none)),
        ]
    )

    private static func values(_ length: LabRSLength, _ behind: LabRSBehind, _ gap: LabRSGap, _ track: LabRSTrack) -> [String: String] {
        ["length": length.rawValue, "behind": behind.rawValue, "gap": gap.rawValue, "track": track.rawValue]
    }

    private static func held(_ options: LabRSOptionSet, _ values: RoundValues) -> LabRSOptionSet {
        var options = options
        options.holdsBars = LabRSHold(rawValue: values["hold"]) == .keep
        return options
    }

    private static func refined(_ values: RoundValues) -> LabRSOptionSet {
        var options = held(.decided, values)
        options.length = LabRSLength(rawValue: values["length"]) ?? .footer
        options.behind = LabRSBehind(rawValue: values["behind"]) ?? .blurUp
        options.gap = LabRSGap(rawValue: values["gap"]) ?? .built
        options.track = LabRSTrack(rawValue: values["track"]) ?? .faint
        return options
    }

    private static func card(_ options: LabRSOptionSet, _ values: RoundValues, drawsBars: Bool = true) -> some View {
        LabRSCard(options: options, drawsBars: drawsBars,
                  columnCount: (LabRSColumns(rawValue: values["columns"]) ?? .forty).count,
                  scrollToken: values["scrollToken"])
    }
}
