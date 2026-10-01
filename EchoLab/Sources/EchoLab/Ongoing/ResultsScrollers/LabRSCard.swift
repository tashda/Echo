import SwiftUI

/// Round 27: a results card as Echo draws it (ContentPanelCards' panel-only card): the AppKit grid
/// filling the card, the footer floating over its bottom on the soft blur, and the bars, track,
/// chip and extras of the options being judged.
struct LabRSCard: View {
    let options: LabRSOptionSet
    /// Echo today keeps the real AppKit bars, which sit above the footer's blur; proposals draw
    /// theirs above everything, so a bar in the footer's zone isn't blurred away.
    var drawsBars = true
    let columnCount: Int
    let scrollToken: String

    @Environment(\.workspaceCardCornerRadius) private var cornerRadius
    @State private var segment: PanelSegment = .results
    @State private var scroll = LabRSScroll()

    /// Room the footer's connection chip and view toggle (left) and its three pills (right) take in
    /// this sample, measured from the exhibit at its design width, with a little air.
    static let chips: (left: CGFloat, right: CGFloat) = (272, 250)

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                LabRSGrid(columnCount: columnCount, setup: setup, scrollToken: scrollToken, scroll: scroll)
                LabRSExtras(extra: options.extra, scroll: scroll, size: proxy.size, footerZone: options.footerZone,
                            footerLift: options.footerLift,
                            footerGap: options.placement.takesFooterGap ? nil : Self.chips)
                if drawsBars {
                    LabRSDrawnBars(options: options, scroll: scroll, size: proxy.size, cornerRadius: cornerRadius)
                }
                VStack(spacing: SpacingTokens.none) {
                    Spacer(minLength: SpacingTokens.none)
                    ZStack {
                        BottomPanelStatusBar(configuration: configuration)
                        // F and G sit in the gap between the connection chip and the pills.
                        LabRSFooterAccessory(placement: options.placement, scroll: scroll)
                            .padding(.leading, Self.chips.left)
                            .padding(.trailing, Self.chips.right)
                    }
                    .frame(height: LayoutTokens.Footer.height)
                    .padding(.bottom, LayoutTokens.Footer.bottomLift + options.footerLift)
                }
            }
        }
        .workspaceCard()
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Workspace.canvas)
    }

    private var setup: LabRSGridSetup {
        let system = !drawsBars
        return LabRSGridSetup(
            footerZone: options.footerZone,
            horizontal: system ? options.horizontalFrame(cornerRadius: cornerRadius, chips: Self.chips) : nil,
            verticalBottom: system ? options.verticalBottom(cornerRadius: cornerRadius, chips: Self.chips) : nil,
            visibility: options.visibility,
            lane: options.lane,
            restBlurHeight: options.restBlurHeight,
            raisedBlurHeight: options.raisedBlurHeight,
            isBlurRaised: options.isBlurRaised(barShown: options.holdsBars || scroll.isScrolling),
            gutterWidth: LabRSOptionSet.gutterWidth)
    }

    private var configuration: BottomPanelStatusBarConfiguration {
        var configuration = BottomPanelStatusBarConfiguration(
            serverName: "dkloosql10-d", databaseName: "ccsLDK17",
            availableSegments: [.results, .messages],
            selectedSegment: segment, onSelectSegment: { segment = $0 },
            onTogglePanel: {}, isPanelOpen: true)
        configuration.metrics = .init(rowCountText: "20,313", rowCountLabel: "rows", durationText: "10s", selectionText: nil)
        configuration.statusBubble = .init(label: "Completed", tint: .green, isPulsing: false)
        configuration.metricsStyle = .pillPerEntry
        return configuration
    }
}
