import SwiftUI

public struct SidebarSectionHeader: View {
    public let title: String

    public init(title: String) {
        self.title = title
    }

    public var body: some View {
        HStack {
            Text(title.uppercased())
                .font(TypographyTokens.caption.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
        .background(ColorTokens.Background.secondary)
    }
}
