import SwiftUI

public struct ToolbarTitleWithSubtitle: View {
    public let title: String
    public let subtitle: String

    public init(title: String, subtitle: String = "") {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            Text(title)
                .font(TypographyTokens.headline)
                .foregroundStyle(ColorTokens.Text.primary)
            
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(TypographyTokens.caption)
                    .italic()
                    .foregroundStyle(ColorTokens.Text.secondary)
            } else {
                // Keep the same height as with subtitle to prevent layout jump
                Text(" ")
                    .font(TypographyTokens.caption)
                    .accessibilityHidden(true)
            }
        }
    }
}
