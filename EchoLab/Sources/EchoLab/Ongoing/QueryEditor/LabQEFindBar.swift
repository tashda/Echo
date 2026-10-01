import SwiftUI

/// Round 28.12: the find bar, open on “orders”. The native one is NSTextView's find bar (usesFindBar,
/// incremental); the others are glass panels Echo would draw, floating over the code.
struct LabQEFindBar: View {
    let place: LabQEFindBarPlace
    let options: LabQEFindOptions
    let count: LabQEFindCount
    let showsReplace: Bool

    var body: some View {
        switch place {
        case .native:
            VStack(spacing: SpacingTokens.xxs) {
                findRow(compact: false)
                if showsReplace { replaceRow }
            }
            .padding(.horizontal, SpacingTokens.xs)
            .padding(.vertical, SpacingTokens.xxs)
            .background(.bar)
            .overlay(alignment: .bottom) { Rectangle().fill(ColorTokens.Separator.primary).frame(height: LayoutTokens.EditorGutter.edgeWidth) }
        case .floating, .bottom, .topCapsule, .safari, .immersiveStrip, .corner, .bottomCapsule, .notch, .spotlight:
            VStack(spacing: SpacingTokens.xxs) {
                findRow(compact: true)
                if showsReplace { replaceRow }
            }
            .padding(SpacingTokens.xs)
            .frame(width: 330)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpacingTokens.sm, style: .continuous))
            .padding(SpacingTokens.xs)
        case .strip:
            VStack(spacing: SpacingTokens.xxs) {
                findRow(compact: false)
                if showsReplace { replaceRow }
            }
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.xxs2)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpacingTokens.sm, style: .continuous))
            .padding(.horizontal, SpacingTokens.xs)
            .padding(.top, SpacingTokens.xs)
        }
    }

    private func findRow(compact: Bool) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            field(symbol: options == .menu ? "magnifyingglass.circle" : "magnifyingglass", text: "orders") {
                Text(verbatim: count == .found ? "2 found" : "1 of 2").foregroundStyle(ColorTokens.Text.secondary)
                if options == .toggles {
                    toggle("Aa", isOn: false); toggle("ab", isOn: false, underline: true); toggle(".*", isOn: false)
                }
            }
            Image(systemName: "chevron.left")
            Image(systemName: "chevron.right")
            if place == .native {
                Text(verbatim: "Done")
            } else {
                Image(systemName: "xmark").foregroundStyle(ColorTokens.Text.secondary)
            }
        }
        .font(TypographyTokens.detail)
    }

    private var replaceRow: some View {
        HStack(spacing: SpacingTokens.xs) {
            field(symbol: "arrow.2.squarepath", text: "orders_2026") { EmptyView() }
            Text(verbatim: "Replace")
            Text(verbatim: "All")
        }
        .font(TypographyTokens.detail)
    }

    private func field<Trailing: View>(symbol: String, text: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: SpacingTokens.xxs) {
            Image(systemName: symbol).foregroundStyle(ColorTokens.Text.secondary)
            Text(verbatim: text)
            Spacer(minLength: SpacingTokens.xs)
            trailing()
        }
        .padding(.horizontal, SpacingTokens.xs)
        .padding(.vertical, SpacingTokens.xxxs)
        .background(ColorTokens.Workspace.card, in: RoundedRectangle(cornerRadius: SpacingTokens.xxs2))
        .overlay(RoundedRectangle(cornerRadius: SpacingTokens.xxs2).strokeBorder(ColorTokens.Separator.primary))
    }

    private func toggle(_ label: String, isOn: Bool, underline: Bool = false) -> some View {
        Text(verbatim: label).underline(underline)
            .foregroundStyle(isOn ? ColorTokens.accent : ColorTokens.Text.secondary)
            .padding(.horizontal, SpacingTokens.xxxs)
    }
}
