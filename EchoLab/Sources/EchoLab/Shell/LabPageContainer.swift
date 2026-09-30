import SwiftUI

/// Title, status and summary above a page's own content.
struct LabPageContainer: View {
    @Environment(LabStore.self) private var store
    let page: LabPage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                HStack(spacing: SpacingTokens.xs) {
                    Text(page.title).font(TypographyTokens.title)
                    if let status = store.status(of: page) {
                        LabStatusPill(status: status)
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

struct LabStatusPill: View {
    let status: LabStatus

    var body: some View {
        Text(status.rawValue)
            .font(TypographyTokens.detail)
            .foregroundStyle(status == .newFeedback ? ColorTokens.Status.warning : ColorTokens.Text.secondary)
            .padding(.horizontal, SpacingTokens.xs)
            .padding(.vertical, SpacingTokens.xxxs)
            .background(ColorTokens.Surface.hover, in: Capsule())
    }
}
