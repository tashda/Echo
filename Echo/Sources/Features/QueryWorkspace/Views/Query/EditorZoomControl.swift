import SwiftUI

/// Round 28.8 (Z1, L2, V0): the zoom as a small glass pill at the editor's bottom left, always
/// shown; its menu offers the steps and Actual Size. ⌘+, ⌘− and ⌘0 are in the View menu.
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
        .foregroundStyle(ColorTokens.Text.secondary)
        .padding(.horizontal, SpacingTokens.xs)
        .padding(.vertical, SpacingTokens.xxs)
        .glassEffect(.regular, in: .capsule)
        .help("Zoom (⌘+ ⌘− ⌘0)")
        .accessibilityLabel("Zoom \(EditorZoom.label(zoom))")
    }
}
