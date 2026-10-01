import SwiftUI

/// A Canvas tool's view controls (round 37.4, CA0): one glass capsule floating at the bottom of
/// the drawing, like the editor's zoom pill. Zoom, fit and what to show act on the drawing, so
/// they sit on it; the tool's actions stay on its header line.
struct CanvasFloatingBar<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            content()
        }
        .font(TypographyTokens.standard)
        .foregroundStyle(ColorTokens.Text.primary)
        .buttonStyle(.plain)
        .padding(.horizontal, SpacingTokens.md)
        .frame(height: LayoutTokens.ToolTab.canvasBarHeight)
        .glassEffect(.regular, in: .capsule)
        .padding(.bottom, SpacingTokens.sm)
    }
}

/// Zoom out, the zoom as a percentage, zoom in and fit, for a `CanvasFloatingBar`.
struct CanvasZoomControls: View {
    let zoom: CGFloat
    let range: ClosedRange<CGFloat>
    let onZoom: (CGFloat) -> Void
    let onFit: () -> Void

    private static let step: CGFloat = 0.1

    var body: some View {
        Button { onZoom(max(range.lowerBound, zoom - Self.step)) } label: { Image(systemName: "minus") }
            .disabled(zoom <= range.lowerBound)
            .help("Zoom Out")
            .accessibilityLabel("Zoom Out")
        Text(Double(zoom).formatted(.percent.precision(.fractionLength(0))))
            .font(TypographyTokens.detail.monospacedDigit())
            .foregroundStyle(ColorTokens.Text.secondary)
            .frame(minWidth: SpacingTokens.xl)
            .onTapGesture(count: 2) { onZoom(1) }
            .help("Double-click for 100%")
        Button { onZoom(min(range.upperBound, zoom + Self.step)) } label: { Image(systemName: "plus") }
            .disabled(zoom >= range.upperBound)
            .help("Zoom In")
            .accessibilityLabel("Zoom In")
        Divider().frame(height: SpacingTokens.md)
        Button(action: onFit) { Image(systemName: "arrow.up.left.and.down.right.magnifyingglass") }
            .help("Zoom to Fit")
            .accessibilityLabel("Zoom to Fit")
    }
}
