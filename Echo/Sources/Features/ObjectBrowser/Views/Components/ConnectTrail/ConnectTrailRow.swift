import SwiftUI

/// A saved connection in the opened trail's list: its mark, its name, and "host · database" under
/// it. The highlighted row follows the pointer and the arrow keys; Return connects it.
struct ConnectTrailRow: View {
    let entry: ConnectTrailEntry
    let color: Color
    let isHighlighted: Bool
    let onHover: () -> Void
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.xs2) {
                mark
                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(entry.name)
                        .font(TypographyTokens.standard)
                        .foregroundStyle(ColorTokens.Text.primary)
                        .lineLimit(1)
                    Text(entry.detail)
                        .font(SidebarRowConstants.trailingFont)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: SpacingTokens.xxs)
            }
            .padding(.horizontal, SpacingTokens.xs)
            .padding(.vertical, SpacingTokens.xxxs)
            .frame(minHeight: SpacingTokens.lg + SpacingTokens.xxs, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous)
                        .fill(ColorTokens.Sidebar.selectedFill)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { if $0 { onHover() } }
    }

    /// The disc and two letters the rail would show for this server.
    private var mark: some View {
        Circle()
            .fill(color)
            .frame(width: SpacingTokens.lg, height: SpacingTokens.lg)
            .overlay {
                Text(ServerRailMonogram.make(from: entry.name))
                    .font(.system(size: SpacingTokens.lg * LayoutTokens.Rail.monogramFontRatio, weight: .bold, design: .rounded))
                    .foregroundStyle(ColorTokens.Text.onFill)
            }
    }
}
