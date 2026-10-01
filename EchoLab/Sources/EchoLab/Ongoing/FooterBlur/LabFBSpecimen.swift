import SwiftUI

/// Round 44: a results card as Echo draws it (the grid, the footer floating over its bottom, the
/// card tint under the footer), with the rows under the footer softened by one technique.
struct LabFBSpecimen: View {
    static let width: CGFloat = 640
    static let height: CGFloat = 280

    let look: LabFBLook
    let isScrolling: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            LabFBGrid(look: look, isScrolling: isScrolling)
            swiftUISoftening
            tint
            LabWKFooter(server: "Test MSSQL · AdventureWorks2022",
                        pills: [.rows("121K"), .time("6s"), .status("Completed", tint: ColorTokens.Status.success)])
                .padding(.bottom, LayoutTokens.Footer.bottomLift)
        }
        .frame(width: Self.width, height: Self.height)
        .background(ColorTokens.Workspace.card)
        .workspaceCard()
    }

    /// BT4 and BT5 are drawn in SwiftUI over the grid.
    @ViewBuilder
    private var swiftUISoftening: some View {
        switch look.technique {
        case .material:
            Rectangle().fill(.ultraThinMaterial)
                .mask(curveGradient(scale: 1))
                .frame(height: look.reach)
                .allowsHitTesting(false)
        case .fade:
            ColorTokens.Workspace.card
                .mask(curveGradient(scale: 1))
                .frame(height: look.reach)
                .allowsHitTesting(false)
        default:
            EmptyView()
        }
    }

    /// The card's colour over the blur, so the footer stays readable. Echo today eases it in over
    /// the footer and the fade along the blur steps' S curve (ContentPanelCards.footerOverlay).
    @ViewBuilder
    private var tint: some View {
        if look.technique == .echoToday {
            let alphas = BackdropEdgeBlurLayerView.fadeAlphas
            ColorTokens.Workspace.card
                .opacity(LayoutTokens.EdgeBlur.tintOpacity)
                .mask(LinearGradient(stops: alphas.reversed().enumerated().map { index, alpha in
                    .init(color: .black.opacity(Double(alpha)), location: CGFloat(index) / CGFloat(alphas.count - 1))
                }, startPoint: .top, endPoint: .bottom))
                .frame(height: LabFBLook.footerZone + LayoutTokens.EdgeBlur.fade)
                .allowsHitTesting(false)
        } else if look.tint > 0, look.technique != .fade {
            ColorTokens.Workspace.card
                .opacity(look.tint)
                .mask(curveGradient(scale: 1))
                .frame(height: look.reach)
                .allowsHitTesting(false)
        }
    }

    /// The technique's curve as a gradient, clear at the top of the reach and full at the edge.
    private func curveGradient(scale: Double) -> LinearGradient {
        let samples = 24
        let stops = (0...samples).map { index -> Gradient.Stop in
            let t = CGFloat(index) / CGFloat(samples)
            let amount = look.curve.amount(t, holdShare: LabFBLook.footerZone / max(look.reach, 1))
            return .init(color: .black.opacity(Double(amount) * scale), location: t)
        }
        return LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
    }
}
