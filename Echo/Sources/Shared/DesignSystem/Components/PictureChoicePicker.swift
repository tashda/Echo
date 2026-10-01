import SwiftUI

/// Round 43.2 (CH1): a choice that changes a look, shown as a small picture of each option with
/// its name beneath. The chosen one is ringed in the accent colour.
public struct PictureChoicePicker<Value: Hashable, Picture: View>: View {
    @Binding private var selection: Value
    private let options: [Value]
    private let title: (Value) -> String
    private let pictureWidth: CGFloat
    @ViewBuilder private let picture: (Value) -> Picture

    public init(
        selection: Binding<Value>,
        options: [Value],
        title: @escaping (Value) -> String,
        pictureWidth: CGFloat = SpacingTokens.xxxl - SpacingTokens.xs,
        @ViewBuilder picture: @escaping (Value) -> Picture
    ) {
        self._selection = selection
        self.options = options
        self.title = title
        self.pictureWidth = pictureWidth
        self.picture = picture
    }

    public var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.xs) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                VStack(spacing: SpacingTokens.xxs) {
                    picture(option)
                        .frame(width: pictureWidth, height: SpacingTokens.xl2)
                        .background(ColorTokens.Workspace.card, in: .rect(cornerRadius: SpacingTokens.xs))
                        .overlay(
                            RoundedRectangle(cornerRadius: SpacingTokens.xs)
                                .strokeBorder(isSelected ? ColorTokens.accent : ColorTokens.Separator.primary,
                                              lineWidth: isSelected ? 2 : 0.5)
                        )
                    Text(title(option))
                        .font(TypographyTokens.detail)
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(isSelected ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture { selection = option }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                .accessibilityLabel(title(option))
            }
        }
    }
}
