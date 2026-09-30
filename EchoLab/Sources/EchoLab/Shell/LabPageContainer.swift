import SwiftUI

/// Title and summary above a page's own content.
struct LabPageContainer: View {
    let page: LabPage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                HStack(spacing: SpacingTokens.xs) {
                    Text(page.title).font(TypographyTokens.title)
                    if let status = page.status {
                        Text(status.rawValue)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .padding(.horizontal, SpacingTokens.xs)
                            .padding(.vertical, SpacingTokens.xxxs)
                            .background(ColorTokens.Surface.hover, in: Capsule())
                    }
                }
                Text(page.summary)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .padding(SpacingTokens.md)
            Divider()
            page.content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(page.title)
    }
}
