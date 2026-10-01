import SwiftUI

/// The scale a specimen is drawn at: the toolbar zoom (100% is the size Echo draws it), unless
/// the room it is given is narrower, then just small enough to fit. Nothing ever scrolls sideways.
@MainActor
enum LabSpecimenScale {
    static func scale(designWidth: CGFloat, available: CGFloat) -> CGFloat {
        let zoom = CGFloat(LabZoom.shared.level)
        guard available > 0 else { return zoom }
        return min(zoom, available / designWidth)
    }
}

/// Draws a specimen designed at a fixed size at the toolbar zoom, centred in the width it is
/// given. When that width is too narrow it is scaled down to fit and says so underneath.
struct LabFitToWidth<Content: View>: View {
    let designWidth: CGFloat
    let designHeight: CGFloat
    @ViewBuilder var content: Content
    @State private var width: CGFloat = 0

    var body: some View {
        let scale = LabSpecimenScale.scale(designWidth: designWidth, available: width)
        VStack(spacing: SpacingTokens.xxs) {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: designHeight * scale)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { width = $0 }
                .overlay(alignment: .top) {
                    content
                        .frame(width: designWidth, height: designHeight)
                        .scaleEffect(scale, anchor: .top)
                        .frame(width: designWidth * scale, height: designHeight * scale, alignment: .top)
                }
            LabScaledToFitNote(scale: scale)
        }
    }
}

/// Like `LabFitToWidth`, for content of unknown height: it is laid out at `designWidth`, then
/// measured, and drawn at the toolbar zoom, scaled down only when the width is too narrow.
struct LabFitToWidthAuto<Content: View>: View {
    let designWidth: CGFloat
    @ViewBuilder var content: Content
    @State private var width: CGFloat = 0
    @State private var measured = CGSize(width: 1, height: 1)

    var body: some View {
        let scale = LabSpecimenScale.scale(designWidth: designWidth, available: width)
        VStack(spacing: SpacingTokens.xxs) {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: max(measured.height, 1) * scale)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { width = $0 }
                .overlay(alignment: .top) {
                    content
                        .frame(width: designWidth, alignment: .topLeading)
                        .fixedSize(horizontal: false, vertical: true)
                        .onGeometryChange(for: CGSize.self, of: { $0.size }) { measured = $0 }
                        .scaleEffect(scale, anchor: .top)
                        .frame(width: designWidth * scale, height: max(measured.height, 1) * scale, alignment: .top)
                }
            LabScaledToFitNote(scale: scale)
        }
    }
}

/// Says a specimen is smaller than the zoom asks for, so a reduced preview is never mistaken
/// for the real size.
private struct LabScaledToFitNote: View {
    let scale: CGFloat

    var body: some View {
        if scale < CGFloat(LabZoom.shared.level) - 0.01 {
            Label("Shown at \(Int((scale * 100).rounded()))% to fit. Hide a panel or show it on its own to see it at \(LabZoom.shared.percent)",
                  systemImage: "arrow.down.right.and.arrow.up.left")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
                .frame(maxWidth: .infinity)
        }
    }
}
