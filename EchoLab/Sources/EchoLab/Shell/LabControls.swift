import SwiftUI

/// The lab's own control look, so buttons and fields are clearly visible on any background:
/// pill buttons with a tinted fill and hairline, and fields that stand out from their column.

/// A pill button. `isOn` shows the tinted, selected state; `prominent` is the one main action.
struct LabPillButtonStyle: ButtonStyle {
    var tint: Color = ColorTokens.accent
    var isOn = false
    var prominent = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let foreground: Color = prominent ? .white : (isOn ? tint : ColorTokens.Text.primary)
        configuration.label
            .font(TypographyTokens.detail.weight(.medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .frame(minHeight: 26)
            .background(
                Capsule().fill(
                    prominent ? tint.opacity(configuration.isPressed ? 0.8 : 1)
                    : (isOn ? tint.opacity(0.16) : Color.primary.opacity(configuration.isPressed ? 0.16 : 0.08)))
            )
            .overlay(Capsule().strokeBorder(isOn ? tint.opacity(0.55) : Color.primary.opacity(0.14), lineWidth: 0.5))
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(Capsule())
    }
}

extension View {
    /// A field surface that stands out from the column behind it.
    func labField(cornerRadius: CGFloat = 8) -> some View {
        background(Color(nsColor: .controlBackgroundColor), in: .rect(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.16), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.05), radius: 1, y: 0.5)
    }

    /// A raised card: the surface, a hairline and a soft shadow.
    func labCard(cornerRadius: CGFloat = 14) -> some View {
        background(ColorTokens.Workspace.card, in: .rect(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}

/// A small section title for a column.
struct LabColumnTitle: View {
    let text: String
    var symbol: String?

    var body: some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol).font(.system(size: 10, weight: .semibold)) }
            Text(text.uppercased()).font(.system(size: 10.5, weight: .semibold)).tracking(0.5)
        }
        .foregroundStyle(ColorTokens.Text.secondary)
    }
}
