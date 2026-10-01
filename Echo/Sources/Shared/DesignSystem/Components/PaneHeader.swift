import SwiftUI

/// The header at the top of a pane inside a tool tab's card (round 33, JH1): the pane's title,
/// an optional grey count, and the pane's actions at the right, all on one 36pt line. Every
/// pane in a tool tab uses the same header so the panes line up.
struct PaneHeader<Actions: View>: View {
    let title: String
    var count: Int?
    @ViewBuilder var actions: () -> Actions

    init(_ title: String, count: Int? = nil, @ViewBuilder actions: @escaping () -> Actions) {
        self.title = title
        self.count = count
        self.actions = actions
    }

    var body: some View {
        HStack(spacing: SpacingTokens.xxs2) {
            Text(title)
                .font(TypographyTokens.headline)
                .foregroundStyle(ColorTokens.Text.primary)
            if let count {
                Text("\(count)")
                    .font(TypographyTokens.detail.monospacedDigit())
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
            Spacer(minLength: SpacingTokens.xs)
            actions()
        }
        .lineLimit(1)
        .padding(.horizontal, SpacingTokens.sm)
        .frame(height: LayoutTokens.ToolTab.paneHeaderHeight)
        .accessibilityElement(children: .contain)
    }
}

extension PaneHeader where Actions == EmptyView {
    init(_ title: String, count: Int? = nil) {
        self.init(title, count: count) { EmptyView() }
    }
}

extension LayoutTokens.ToolTab {
    /// A pane header's height (round 33, JH1).
    static let paneHeaderHeight: CGFloat = SpacingTokens.lg + SpacingTokens.sm
}
