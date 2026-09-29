#if DEBUG
import SwiftUI

/// Round 14 · tab bar and pages: the Maybes from the design board, drawn with SwiftUI on the
/// real canvas and card tokens. Activity Monitor is the tool with pages; Query 2 is running.
struct LabRound14TabsPlayground: View {
    @State private var speed: LabSpeed = .standard
    @State private var pageStyle: LabRound14PageStyle = .drawer
    @State private var pageBarStyle: LabRound14BarStyle = .sunk
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var animation: Animation { speed.spring(reduceMotion: reduceMotion) }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.lg) {
            LabStage(title: "Bar styles, each with the ST1 drawer") {
                LabPicker(title: "Speed", selection: $speed, options: LabSpeed.allCases)
                Text("Switch between Activity Monitor and a query tab to see the drawer open and fold away.")
                    .foregroundStyle(ColorTokens.Text.secondary)
            } content: {
                VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                    ForEach(LabRound14BarStyle.allCases) { style in
                        section(title: style.rawValue, summary: style.summary) {
                            LabRound14TabWindow(style: style, pageStyle: .drawer, animation: animation)
                        }
                    }
                }
                .padding(SpacingTokens.md)
            }

            LabStage(title: "How a tool's pages open") {
                LabPicker(title: "Pages", selection: $pageStyle, options: LabRound14PageStyle.allCases)
                LabPicker(title: "Bar", selection: $pageBarStyle, options: LabRound14BarStyle.allCases)
            } content: {
                section(title: pageStyle.rawValue, summary: pageStyle.summary) {
                    LabRound14TabWindow(style: pageBarStyle, pageStyle: pageStyle, animation: animation)
                        .id("\(pageStyle.id)-\(pageBarStyle.id)")
                }
                .padding(SpacingTokens.md)
            }
        }
    }

    private func section(title: String, summary: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text(title).font(TypographyTokens.headline)
            Text(summary)
                .font(TypographyTokens.callout)
                .foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: LayoutTokens.DesignLabRound14.windowWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            content()
        }
    }
}
#endif
