import SwiftUI

/// The pinned card header (Design/05-components.md › Explorer tree): once a server's own header
/// has scrolled away, "server › database" pins at the top of its card over a soft blur that
/// fades out downward, so rows dissolve under it with no hard edge. Two actions appear on hover.
struct ExplorerPinnedPathBar: View {
    let height: CGFloat
    let serverName: String
    let databaseName: String?
    let onScrollToServer: () -> Void
    let onScrollToDatabase: () -> Void
    let onCollapseOtherDatabases: () -> Void

    @State private var isHovering = false
    @Environment(\.workspaceCardCornerRadius) private var cornerRadius

    var body: some View {
        HStack(spacing: SpacingTokens.xxs) {
            Button(action: onScrollToServer) {
                Text(serverName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(ColorTokens.Text.primary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Scroll to \(serverName)")

            if let databaseName {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .accessibilityHidden(true)

                Button(action: onScrollToDatabase) {
                    Text(databaseName)
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .contentTransition(.opacity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Scroll to \(databaseName)")
            }

            Spacer(minLength: SpacingTokens.xs)

            HStack(spacing: SpacingTokens.xxxs) {
                actionButton("arrow.up.to.line", help: "Top of Server", action: onScrollToServer)
                if databaseName != nil {
                    actionButton(
                        "rectangle.compress.vertical",
                        help: "Collapse Other Databases",
                        action: onCollapseOtherDatabases
                    )
                }
            }
            .opacity(isHovering ? 1 : 0)
            .allowsHitTesting(isHovering)
        }
        .padding(.leading, SpacingTokens.sm)
        .padding(.trailing, SpacingTokens.xs)
        .frame(height: height)
        .background(alignment: .top) { softEdge }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.18), value: isHovering)
        .animation(.easeInOut(duration: 0.22), value: databaseName)
    }

    /// A blur of the rows underneath that fades out downward, like the system's soft scroll
    /// edge, so there is no hard back or bottom line. Rounded at the top to follow the card.
    private var softEdge: some View {
        UnevenRoundedRectangle(topLeadingRadius: cornerRadius, topTrailingRadius: cornerRadius, style: .continuous)
            .fill(.regularMaterial)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.5),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: height + LayoutTokens.Workspace.pinnedHeaderFade)
            .allowsHitTesting(false)
    }

    private func actionButton(_ systemImage: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: 22, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

/// Shows the pinned path while the Explorer is scrolled past a server's header. Reads the
/// scroll context from the rail bridge so that only this overlay redraws while scrolling.
struct ExplorerPinnedPathOverlay: View {
    let bridge: ServerRailBridge
    /// Height of a server header row, so the glass covers it exactly.
    let headerHeight: CGFloat
    let isEnabled: Bool
    let sessions: [ConnectionSession]
    let onScrollToServer: (UUID) -> Void
    let onScrollToDatabase: (UUID, String) -> Void
    let onCollapseOtherDatabases: (ConnectionSession, String) -> Void

    var body: some View {
        let context = bridge.topVisibleContext
        let pinnedID = isEnabled && context.isScrolledPastServerHeader ? context.connectionID : nil

        ZStack(alignment: .top) {
            if let pinnedID, let session = sessions.first(where: { $0.connection.id == pinnedID }) {
                ExplorerPinnedPathBar(
                    height: headerHeight,
                    serverName: displayName(for: session.connection),
                    databaseName: context.databaseName,
                    onScrollToServer: { onScrollToServer(pinnedID) },
                    onScrollToDatabase: {
                        if let databaseName = context.databaseName {
                            onScrollToDatabase(pinnedID, databaseName)
                        }
                    },
                    onCollapseOtherDatabases: {
                        if let databaseName = context.databaseName {
                            onCollapseOtherDatabases(session, databaseName)
                        }
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: pinnedID)
    }

    private func displayName(for connection: SavedConnection) -> String {
        let name = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? connection.host : name
    }
}
