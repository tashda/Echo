import SwiftUI

/// The headings inside a server card: the server's name at the top, and the server-level
/// sections under it (Databases, Security, Agent Jobs…), drawn as Finder-style headings whose
/// children start at the card's left edge.
extension ObjectBrowserRowView {
    func connectionSectionHeader(session: ConnectionSession, showsDisclosure: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SidebarRowConstants.iconTextSpacing) {
            Text(serverDisplayName(session))
                .font(SidebarRowConstants.serverHeaderFont)
                .foregroundStyle(ColorTokens.Text.primary)
                .lineLimit(1)

            Spacer(minLength: SpacingTokens.xxs)

            if case .connecting = session.connectionState {
                ProgressView()
                    .controlSize(.mini)
            } else if case .testing = session.connectionState {
                ProgressView()
                    .controlSize(.mini)
            } else if let product = serverProductLabel(session) {
                Text(product)
                    .font(SidebarRowConstants.trailingFont)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .lineLimit(1)
            }

            if showsDisclosure {
                disclosureChevron
            }
        }
        .padding(.leading, SpacingTokens.sm)
        .padding(.trailing, SidebarRowConstants.rowTrailingPadding + SidebarRowConstants.rowOuterHorizontalPadding)
        .padding(.top, SpacingTokens.sm)
        .padding(.bottom, SpacingTokens.xxxs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onHover { isHeaderHovering = $0 }
    }

    /// A server-level folder as a heading: small semibold grey title, its count, and a chevron at
    /// the trailing edge that shows while collapsed or hovered.
    func sectionHeading(title: String, count: Int?) -> some View {
        Button(action: onActivate) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xxs2) {
                Text(title)
                    .font(SidebarRowConstants.sectionHeadingFont)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
                countLabel(count)
                Spacer(minLength: SpacingTokens.xxs)
                disclosureChevron
            }
            .padding(.leading, SpacingTokens.sm)
            .padding(.trailing, SidebarRowConstants.rowTrailingPadding + SidebarRowConstants.rowOuterHorizontalPadding)
            .padding(.top, LayoutTokens.Workspace.treeSectionTopPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onHover { isHeaderHovering = $0 }
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityAddTraits(.isHeader)
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
    }

    /// Finder-style: the chevron rotates, and an open section only shows it on hover.
    private var disclosureChevron: some View {
        Image(systemName: "chevron.right")
            .font(SidebarRowConstants.sectionChevronFont)
            .foregroundStyle(ColorTokens.Text.tertiary)
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
            .frame(width: SidebarRowConstants.chevronWidth)
            .opacity(isHeaderHovering || !isExpanded ? 1 : 0)
            .animation(.snappy(duration: 0.2), value: isExpanded)
            .animation(.easeInOut(duration: 0.15), value: isHeaderHovering)
    }
}
