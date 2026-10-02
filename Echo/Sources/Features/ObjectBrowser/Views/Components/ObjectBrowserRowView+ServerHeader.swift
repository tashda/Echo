import SwiftUI

/// The server header's look (round 30.1): the name and product line in the chosen style, and how
/// far its colour reaches. The wash and the banner are `ServerHeaderBackdrop`.
extension ObjectBrowserRowView {
    func serverHeaderPaint(for connection: SavedConnection) -> ServerHeaderPaint {
        // Automatic type colour looks at the colour as it is in this appearance (round 53, TC1).
        let hex = environmentState.connectionStore.currentColorHex(of: connection)
        let rgb = ServerColorPalette.components(forStored: hex, isDark: colorScheme == .dark)
        return ServerHeaderPaint(settings: projectStore.globalSettings,
                                 serverColor: environmentState.connectionStore.currentColor(of: connection),
                                 accent: resolvedAccentColor(for: connection),
                                 isLightFill: rgb.map { ServerHeaderContrast.prefersDarkType(red: $0.red, green: $0.green, blue: $0.blue) } ?? false)
    }

    /// The title banner's lines (round 53, F5): small capitals over the name in the chosen
    /// typeface and size. Open, the capitals can name the dock's section; closed, never.
    func titleBannerLines(_ session: ConnectionSession, paint: ServerHeaderPaint) -> some View {
        let look = paint.look
        let eyebrow = ServerHeaderEyebrow.text(
            line: look.eyebrow,
            engine: ServerHeaderEyebrow.engineName(for: session.connection.databaseType),
            section: dockSectionTitles[session.connection.id],
            isOpen: isExpanded
        )
        return VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            if let eyebrow {
                Text(eyebrow)
                    .font(ServerHeaderTokens.eyebrowFont)
                    .tracking(ServerHeaderTokens.eyebrowTracking)
                    .foregroundStyle(paint.ink.opacity(ServerHeaderTokens.eyebrowOpacity))
                    .contentTransition(.identity)
                    .lineLimit(1)
            }
            Text(serverDisplayName(session))
                .font(ServerHeaderTokens.nameFont(look))
                .foregroundStyle(paint.ink)
                .lineLimit(1)
            if look.eyebrow == .none {
                Text(productLine(session, includesSection: isExpanded))
                    .contentTransition(.identity)
                    .font(SidebarRowConstants.trailingFont)
                    .foregroundStyle(paint.ink.opacity(ServerHeaderTokens.eyebrowOpacity))
                    .lineLimit(1)
            }
        }
    }

    /// The name and product line: on the card, on a banner (white), beside a bar of colour (HD12),
    /// or with the name on a tinted glass plate (HD7).
    @ViewBuilder
    func serverHeaderLines(_ session: ConnectionSession, paint: ServerHeaderPaint) -> some View {
        if paint.isTitleBanner {
            titleBannerLines(session, paint: paint)
        } else {
            classicHeaderLines(session, paint: paint)
        }
    }

    @ViewBuilder
    private func classicHeaderLines(_ session: ConnectionSession, paint: ServerHeaderPaint) -> some View {
        let lines = VStack(alignment: .leading, spacing: SpacingTokens.micro) {
            serverName(session, paint: paint)
            Text(productLine(session))
                // The section name swaps with the rows; morphing the text redraws it on the CPU.
                .contentTransition(.identity)
                .font(SidebarRowConstants.trailingFont)
                .foregroundStyle(paint.isOnFill ? ColorTokens.Text.onFill.opacity(0.85) : ColorTokens.Text.tertiary)
                .lineLimit(1)
        }
        if paint.style == .bar {
            // In the header's leading padding, so the name stays where the plain header's is.
            lines.overlay(alignment: .leading) {
                Capsule()
                    .fill(paint.fill)
                    .frame(width: SpacingTokens.nano)
                    .padding(.vertical, SpacingTokens.micro)
                    .offset(x: -(SpacingTokens.xxs1 + SpacingTokens.nano))
            }
        } else {
            lines
        }
    }

    @ViewBuilder
    private func serverName(_ session: ConnectionSession, paint: ServerHeaderPaint) -> some View {
        let name = Text(serverDisplayName(session)).font(serverNameFont).lineLimit(1)
        if paint.style == .plate {
            name.foregroundStyle(ColorTokens.Text.primary)
                .padding(.horizontal, SpacingTokens.xs2)
                .padding(.vertical, SpacingTokens.xxxs)
                .glassEffect(.regular.tint(paint.fill.opacity(paint.color == nil ? 0.08 : 0.28)), in: .capsule)
                .padding(.leading, -SpacingTokens.xxs)
        } else {
            name.foregroundStyle(paint.isOnFill ? ColorTokens.Text.onFill : ColorTokens.Text.primary)
        }
    }

    /// How far the header's colour reaches: through the dock while the card is open (the header
    /// alone without a dock), the whole card while it is closed.
    var serverBackdropHeight: CGFloat {
        let base = ObjectBrowserOutlineView.baseRowHeight(for: projectStore.globalSettings.sidebarDensity)
        let header = base + ObjectBrowserNode.Row.serverHeaderExtraHeight
            + ObjectBrowserNode.Row.titleBannerExtraHeight(settings: projectStore.globalSettings)
        guard isExpanded else { return header + LayoutTokens.Workspace.treeCardBottomPadding }
        guard case .dock? = node.children.first?.row else { return header }
        return header + base + LayoutTokens.ExplorerDock.extraHeight
    }
}
