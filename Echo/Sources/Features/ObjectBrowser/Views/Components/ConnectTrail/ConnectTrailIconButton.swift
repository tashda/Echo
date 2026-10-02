import SwiftUI

/// An icon-only button in the connect drawer's header: New Connection, Manage Connections, Quick
/// Connect and the close ×. All four share one size.
struct ConnectTrailIconButton: View {
    let symbol: String
    let title: String
    var font: Font = .system(size: LayoutTokens.Rail.toolSymbolSize, weight: .medium)
    let action: () -> Void

    @Environment(\.echoMotion) private var motion
    @State private var isHovering = false

    static let size = SpacingTokens.lg + SpacingTokens.xxs

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(font)
                .foregroundStyle(isHovering ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
                .frame(width: Self.size, height: Self.size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(title)
        .accessibilityLabel(title)
        .onHover { isHovering = $0 }
        .animation(motion.hover, value: isHovering)
    }
}
