import SwiftUI

/// Round 27: a results card as Echo draws it (ContentPanelCards' panel-only card): the AppKit grid
/// filling the card, and the footer floating over its bottom on the soft blur, lifted 4pt.
struct LabRSCard: View {
    let placement: LabRSPlacement
    let columnCount: Int
    let scrollToken: String

    @Environment(\.workspaceCardCornerRadius) private var cornerRadius
    @State private var segment: PanelSegment = .results
    @State private var scroll = LabRSScroll()

    private var footerZone: CGFloat { LayoutTokens.Footer.height + LayoutTokens.Footer.bottomLift + placement.extraFooterLift }

    /// Room the footer's connection chip (left) and its three pills (right) take in this sample,
    /// read from the exhibit at its design width, with the footer's own padding.
    private static let chips: (left: CGFloat, right: CGFloat) = (220, 250)

    var body: some View {
        ZStack(alignment: .bottom) {
            LabRSGrid(
                columnCount: columnCount,
                footerZone: footerZone,
                scrollerInsets: placement.scrollerInsets(footerZone: footerZone, cornerRadius: cornerRadius, chips: Self.chips),
                scrollToken: scrollToken,
                showsSystemBar: placement.showsSystemBar,
                scroll: scroll
            )
            BottomPanelStatusBar(configuration: configuration)
                .padding(.bottom, LayoutTokens.Footer.bottomLift + placement.extraFooterLift)
            // F and G sit in the gap between the connection chip and the pills.
            LabRSFooterAccessory(placement: placement, scroll: scroll)
                .padding(.leading, Self.chips.left)
                .padding(.trailing, Self.chips.right)
                .frame(height: LayoutTokens.Footer.height)
                .padding(.bottom, LayoutTokens.Footer.bottomLift)
        }
        .workspaceCard()
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Workspace.canvas)
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
