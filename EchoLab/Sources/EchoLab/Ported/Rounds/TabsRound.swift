import SwiftUI

/// Round 14 · tab bar and pages, as a `RoundSpec`. You answered it on the design board: Round 9's
/// strip on one line, and a tool's pages unfold inside its tab.
@MainActor
enum TabsRound {
    private static let size = CGSize(width: LayoutTokens.DesignLabRound14.windowWidth, height: 330)

    static let spec = RoundSpec(
        controls: [
            .of("bar", "Tab bar", LabRound14BarStyle.self, default: .today,
                question: "Compare the bar against the tree and editor cards, in light and dark. Which tab bar?",
                recommend: .today,
                why: "You chose Round 9's strip on one line: the grey plate with the raised white active tab. N1R and N7 were rejected.",
                summary: \.summary),
            .of("pages", "Tool pages", LabRound14PageStyle.self, default: .unfold,
                question: "Switch between Activity Monitor and Query 2. How should a tool's pages open?",
                recommend: .unfold,
                why: "You chose ST2: the tool's tab unfolds and shows its pages inside itself. Drawer, tab group, page menu and second bar were rejected.",
                summary: \.summary),
            .of("speed", "Speed", LabSpeed.self, default: .standard),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Round 9's strip with the tool's pages unfolding in its tab.",
                  isEchoToday: true, isWide: true, designWidth: size.width, designHeight: size.height) { values in
                TabsWindow(bar: .today, pages: .unfold, values: values)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls: pick a bar and a way to open pages.",
                  isWide: true, designWidth: size.width, designHeight: size.height) { values in
                TabsWindow(bar: LabRound14BarStyle(rawValue: values["bar"]) ?? .today,
                           pages: LabRound14PageStyle(rawValue: values["pages"]) ?? .unfold, values: values)
                    .id("\(values["bar"])-\(values["pages"])")
            },
        ],
        presets: [
            .init(id: "chosen", name: "What you chose", summary: "R9 strip, tab unfolds.", values: [
                "bar": LabRound14BarStyle.today.rawValue, "pages": LabRound14PageStyle.unfold.rawValue], isRecommended: true),
        ]
    )
}

private struct TabsWindow: View {
    let bar: LabRound14BarStyle
    let pages: LabRound14PageStyle
    let values: RoundValues
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        LabRound14TabWindow(style: bar, pageStyle: pages,
                            animation: (LabSpeed(rawValue: values["speed"]) ?? .standard).spring(reduceMotion: reduceMotion))
    }
}
