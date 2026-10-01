import SwiftUI

/// The bar: FB5's glass capsule with glass circles; the chevron opens Replace with the chosen motion.
extension LabQESearchReplacePlayground {
    var bar: some View {
        GlassEffectContainer(spacing: SpacingTokens.xs) {
            HStack(alignment: .top, spacing: SpacingTokens.xs) {
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        findRow
                        if isReplaceOpen, opening != .morph {
                            replaceRow.transition(rowTransition)
                        }
                    }
                    .padding(.horizontal, SpacingTokens.md).padding(.vertical, SpacingTokens.xs)
                    .frame(width: 400, alignment: .leading)
                    .clipped()
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpacingTokens.lg, style: .continuous))
                    .glassEffectID("find", in: glassSpace)
                    if isReplaceOpen, opening == .morph {
                        replaceRow
                            .padding(.horizontal, SpacingTokens.md).padding(.vertical, SpacingTokens.xs)
                            .frame(width: 400, alignment: .leading)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpacingTokens.lg, style: .continuous))
                            .glassEffectID("replace", in: glassSpace)
                            .glassEffectTransition(.matchedGeometry)
                    }
                }
                circle("chevron.left") { current = max(current - 1, 0) }
                circle("chevron.right") { current = min(current + 1, max(matches.count - 1, 0)) }
                circle("arrow.counterclockwise") { reset() }
            }
        }
        .font(TypographyTokens.detail)
    }

    private var rowTransition: AnyTransition {
        switch opening {
        case .instant: .identity
        case .slide: .move(edge: .top).combined(with: .opacity)
        default: .opacity
        }
    }

    private var findRow: some View {
        HStack(spacing: SpacingTokens.xs) {
            Button {
                withAnimation(opening.animation(motion)) { isReplaceOpen.toggle() }
            } label: {
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isReplaceOpen ? 90 : 0))
                    .frame(width: SpacingTokens.sm, height: SpacingTokens.sm)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isReplaceOpen ? "Hide Replace" : "Show Replace (\(shortcuts.replaceKeys))")
            Image(systemName: "magnifyingglass").foregroundStyle(ColorTokens.Text.secondary)
            TextField("Find", text: $find, prompt: Text("Find")).textFieldStyle(.plain)
                .onChange(of: find) { _, _ in status = nil; current = 0 }
            Text(verbatim: status ?? "\(matches.count) found").foregroundStyle(ColorTokens.Text.secondary).fixedSize()
        }
    }

    private var replaceRow: some View {
        HStack(spacing: SpacingTokens.xs) {
            Color.clear.frame(width: SpacingTokens.sm, height: 1)
            Image(systemName: "arrow.2.squarepath").foregroundStyle(ColorTokens.Text.secondary)
            TextField("Replace", text: $replacement, prompt: Text("Replace with")).textFieldStyle(.plain)
                .onSubmit { replaceCurrent() }
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
