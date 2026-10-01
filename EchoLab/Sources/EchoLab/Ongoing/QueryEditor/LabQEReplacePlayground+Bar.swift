import SwiftUI

/// The playground's bar: FB5's glass capsule with glass buttons, laid out per replace style.
extension LabQEReplacePlayground {
    @ViewBuilder
    var bar: some View {
        GlassEffectContainer(spacing: SpacingTokens.xs) {
            HStack(alignment: .top, spacing: SpacingTokens.xs) {
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    findRow
                    if style != .ownCapsule, style != .expand || isReplaceOpen { replaceRow }
                }
                .padding(.horizontal, SpacingTokens.md).padding(.vertical, SpacingTokens.xs)
                .frame(width: style == .ownCapsule ? 230 : 370)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpacingTokens.lg, style: .continuous))
                if style == .ownCapsule {
                    replaceRow
                        .padding(.horizontal, SpacingTokens.md).padding(.vertical, SpacingTokens.xs)
                        .frame(width: 270)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpacingTokens.lg, style: .continuous))
                } else {
                    circle("chevron.left") { current = max(current - 1, 0) }
                    circle("chevron.right") { current = min(current + 1, max(matches.count - 1, 0)) }
                    circle("arrow.counterclockwise") { reset() }
                }
            }
        }
        .font(TypographyTokens.detail)
    }

    private var findRow: some View {
        HStack(spacing: SpacingTokens.xs) {
            if style == .expand {
                Button { isReplaceOpen.toggle() } label: {
                    Image(systemName: isReplaceOpen ? "chevron.down" : "chevron.right").frame(width: SpacingTokens.sm)
                }
                .buttonStyle(.plain)
                .help(isReplaceOpen ? "Hide Replace" : "Show Replace")
            }
            Image(systemName: "magnifyingglass").foregroundStyle(ColorTokens.Text.secondary)
            TextField("Find", text: $find, prompt: Text("Find")).textFieldStyle(.plain)
            Text(verbatim: "\(matches.count) found").foregroundStyle(ColorTokens.Text.secondary).fixedSize()
        }
    }

    private var replaceRow: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "arrow.2.squarepath").foregroundStyle(ColorTokens.Text.secondary)
            TextField("Replace", text: $replacement, prompt: Text("Replace with")).textFieldStyle(.plain)
            Button("Replace") { replaceCurrent() }.buttonStyle(.glass).controlSize(.small).disabled(matches.isEmpty)
            Button("Replace All") { replaceAll() }.buttonStyle(.glassProminent).controlSize(.small).disabled(matches.isEmpty)
        }
    }

    private func circle(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).frame(width: SpacingTokens.xl, height: SpacingTokens.xl).contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
    }
}
