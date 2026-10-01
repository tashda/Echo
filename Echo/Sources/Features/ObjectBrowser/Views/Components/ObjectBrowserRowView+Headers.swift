import SwiftUI

/// The headings inside a server card: the server's name at the top, and the server-level
/// sections under it (Databases, Security, Agent Jobs…), drawn as Finder-style headings whose
/// children start at the card's left edge.
extension ObjectBrowserRowView {
    /// The server's name, bold and sized by the sidebar size, with its product and release under
    /// it (round 16; the full build is in the tooltip). The chevron is centred on the two lines
    /// (round 30.2, CP1). Open, the lines sit 12pt from the card's top, above the dock; closed,
    /// the lines and the chevron are centred in the card (the slot plus the card's bottom padding),
    /// and they glide between the two as the card folds. Its look is Settings › Appearance › Server
    /// Header and Server Header Color (round 30.1, `ServerHeaderPaint`).
    func connectionSectionHeader(session: ConnectionSession, showsDisclosure: Bool) -> some View {
        let paint = serverHeaderPaint(for: session.connection)
        return HStack(alignment: .center, spacing: SidebarRowConstants.iconTextSpacing) {
            serverHeaderLines(session, paint: paint)

            Spacer(minLength: SpacingTokens.xxs)

            if case .connecting = session.connectionState {
                ProgressView()
                    .controlSize(.mini)
            } else if case .testing = session.connectionState {
                ProgressView()
                    .controlSize(.mini)
            }

            if showsDisclosure {
                disclosureChevron(onFill: paint.isOnFill)
            }
        }
        .padding(.leading, SpacingTokens.sm)
        .padding(.trailing, SidebarRowConstants.rowTrailingPadding + SidebarRowConstants.rowOuterHorizontalPadding)
        .padding(.top, isExpanded ? SpacingTokens.sm : LayoutTokens.Workspace.treeCardBottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isExpanded ? .topLeading : .leading)
        .background(alignment: .top) {
            ServerHeaderBackdrop(paint: paint, height: serverBackdropHeight, isClosed: !isExpanded)
        }
        .contentShape(Rectangle())
        .onHover { isHeaderHovering = $0 }
    }

    /// The product and release, then the dock's current section (round 19).
    func productLine(_ session: ConnectionSession) -> String {
        let product = ServerProductLabel.label(
            rawVersion: session.databaseStructure?.serverVersion ?? session.connection.serverVersion,
            databaseType: session.connection.databaseType
        )
        guard let section = dockSectionTitles[session.connection.id] else { return product }
        return "\(product) · \(section)"
    }

    /// Bold, one step with the sidebar size: 13pt at the default size.
    var serverNameFont: Font {
        switch projectStore.globalSettings.sidebarDensity {
        case .compact: TypographyTokens.detail.weight(.bold)
        case .small: TypographyTokens.caption2.weight(.bold)
        case .medium: TypographyTokens.standard.weight(.bold)
        case .large: TypographyTokens.prominent.weight(.bold)
        }
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
                disclosureChevron()
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
    /// White on a banner header (round 30.1, HD16).
    private func disclosureChevron(onFill: Bool = false) -> some View {
        Image(systemName: "chevron.right")
            .font(SidebarRowConstants.sectionChevronFont)
            .foregroundStyle(onFill ? ColorTokens.Text.onFill : ColorTokens.Text.tertiary)
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
            .frame(width: SidebarRowConstants.chevronWidth)
            .opacity(isHeaderHovering || !isExpanded ? 1 : 0)
            .animation(motion.expand, value: isExpanded)
            .animation(.easeInOut(duration: 0.15), value: isHeaderHovering)
    }
}
