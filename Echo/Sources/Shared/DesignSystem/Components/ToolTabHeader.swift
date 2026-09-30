import SwiftUI

/// The one header every tool tab starts with (Design/05-components › Tool tabs, TT2): the
/// tool's tinted icon, its title, the server and how fresh the data is, and the tool's own
/// actions on the right. It sits on the canvas above the tool's cards.
struct ToolTabHeader<Actions: View>: View {
    let systemImage: String
    let tint: Color
    let title: String
    let subtitle: Text?
    @ViewBuilder var actions: () -> Actions

    init(systemImage: String, tint: Color, title: String, subtitle: Text? = nil, @ViewBuilder actions: @escaping () -> Actions) {
        self.systemImage = systemImage
        self.tint = tint
        self.title = title
        self.subtitle = subtitle
        self.actions = actions
    }

    var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            TintedIcon(systemImage: systemImage, tint: tint, size: LayoutTokens.ToolTab.iconSize,
                       boxSize: LayoutTokens.ToolTab.iconBoxSize, cornerRadius: LayoutTokens.ToolTab.iconCornerRadius)
            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                Text(title)
                    .font(TypographyTokens.standard.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.primary)
                if let subtitle {
                    subtitle
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .monospacedDigit()
                }
            }
            .lineLimit(1)
            Spacer(minLength: SpacingTokens.sm)
            actions()
        }
        .padding(.horizontal, SpacingTokens.xs)
        .frame(height: LayoutTokens.ToolTab.headerHeight)
        .accessibilityElement(children: .contain)
    }
}

extension ToolTabHeader where Actions == EmptyView {
    init(systemImage: String, tint: Color, title: String, subtitle: Text? = nil) {
        self.init(systemImage: systemImage, tint: tint, title: title, subtitle: subtitle) { EmptyView() }
    }
}

extension LayoutTokens {
    /// Tool tabs (TT1–TT3).
    enum ToolTab {
        static let headerHeight: CGFloat = 40
        static let iconSize: CGFloat = 14
        static let iconBoxSize: CGFloat = 28
        static let iconCornerRadius: CGFloat = SpacingTokens.xxs3
        static let tileHeight: CGFloat = 76
        static let tileSparklineHeight: CGFloat = 28
    }
}
