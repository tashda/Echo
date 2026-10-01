import SwiftUI

/// Round 43.2 (CH1, PC0): the editor's visual choices drawn small, one picture per option.
struct EditorGutterPicture: View {
    let style: EditorGutterStyle

    var body: some View {
        HStack(spacing: SpacingTokens.xxs) {
            VStack(alignment: .trailing, spacing: SpacingTokens.xxxs) {
                ForEach(1..<4, id: \.self) { number in
                    Text("\(number)").font(TypographyTokens.compact.monospaced()).foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .padding(.horizontal, SpacingTokens.xxs)
            .frame(maxHeight: .infinity)
            .background {
                switch style {
                case .subtle: Color.clear
                case .tinted: ColorTokens.Sidebar.selectedFill
                case .lane:
                    RoundedRectangle(cornerRadius: SpacingTokens.xxs).fill(ColorTokens.Sidebar.selectedFill).padding(SpacingTokens.xxxs)
                case .hairline:
                    HStack { Spacer(); Rectangle().fill(ColorTokens.Separator.primary).frame(width: 1) }
                }
            }
            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                ForEach([0.8, 0.5, 0.65], id: \.self) { width in
                    Capsule().fill(ColorTokens.Text.tertiary.opacity(0.4)).frame(width: 30 * width, height: 3)
                }
            }
            Spacer(minLength: 0)
        }
        .clipShape(.rect(cornerRadius: SpacingTokens.xs))
    }
}

/// A mark on a word, with the corners and strength it would have.
struct EditorMarkPicture: View {
    let corners: EditorMarkCorners
    let strength: EditorMarkStrength

    var body: some View {
        Text("bag")
            .font(TypographyTokens.detail.monospaced())
            .padding(.horizontal, SpacingTokens.xxs)
            .padding(.vertical, SpacingTokens.micro)
            .background(
                ColorTokens.accent.opacity(0.12 * Double(strength.multiplier)),
                in: RoundedRectangle(cornerRadius: corners.radius(forHeight: 16), style: .continuous)
            )
    }
}
