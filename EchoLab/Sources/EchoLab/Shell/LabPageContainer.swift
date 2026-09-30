import SwiftUI

/// Title and summary above a page's own content.
struct LabPageContainer: View {
    let page: LabPage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                Text(page.title).font(TypographyTokens.title)
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
