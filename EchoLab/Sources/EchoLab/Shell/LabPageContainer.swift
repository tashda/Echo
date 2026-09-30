import SwiftUI

/// Title, status and summary above a page's own content.
struct LabPageContainer: View {
    @Environment(LabStore.self) private var store
    let page: LabPage

    var body: some View {
        if page.ownsHeader {
            page.content().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                LabRoundInfoBox(page: page).padding(SpacingTokens.md)
                page.content().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
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
