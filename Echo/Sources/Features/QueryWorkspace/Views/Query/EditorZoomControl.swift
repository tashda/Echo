import SwiftUI

/// Round 28.8 (Z1, L2, V0): the zoom as a small glass pill at the editor's bottom left, always
/// shown; its menu offers the steps and Actual Size. ⌘+, ⌘− and ⌘0 are in the View menu.
/// Round 31 (ZH1, ZT1): as tall as the footer's pills, with primary text like the server pill.
struct EditorZoomControl: View {
    @Binding var zoom: Double

    var body: some View {
        Menu {
            ForEach(EditorZoom.levels, id: \.self) { level in
                Button(EditorZoom.label(level)) { zoom = level }
            }
            Divider()
            Button("Actual Size") { zoom = EditorZoom.actualSize }
        } label: {
            Text(EditorZoom.label(zoom)).monospacedDigit()
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.visible)
        .fixedSize()
        .font(TypographyTokens.detail)
        .foregroundStyle(ColorTokens.Text.primary)
        .padding(.horizontal, LayoutTokens.Footer.chipHorizontalPadding)
        .frame(height: LayoutTokens.Footer.chipHeight)
        .glassEffect(.regular, in: .capsule)
        .help("Zoom (⌘+ ⌘− ⌘0)")
        .accessibilityLabel("Zoom \(EditorZoom.label(zoom))")
    }

    /// Round 31: from the editor card's laid-out bottom to the pill's bottom. With results (no
    /// footer in the card) the pill sits where the footer's pills sit in theirs (ZW1); with the
    /// footer in the editor's card it stacks above the server pill, the same 9pt apart (ZN2).
    /// `hiddenBelow` keeps it on the card's visible edge while the results grow or fold.
    static func bottomInset(footerInCard: Bool, hiddenBelow: CGFloat = 0) -> CGFloat {
        let inset = LayoutTokens.Footer.pillInset
        return hiddenBelow + (footerInCard ? inset + LayoutTokens.Footer.chipHeight + inset : inset)
    }

    /// Round 31: in from the card's leading edge as far as the footer's pills (12pt).
    static let leadingInset: CGFloat = SpacingTokens.sm
}
