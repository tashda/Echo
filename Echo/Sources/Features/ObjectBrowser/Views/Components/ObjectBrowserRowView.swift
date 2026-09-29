import SwiftUI
import AppKit
import SQLServerKit

struct ObjectBrowserRowView: View {
    let node: ObjectBrowserNode
    let isExpanded: Bool
    let isSelected: Bool
    let outlineLevel: Int
    let outlineOffset: CGFloat
    let isHighlighted: Bool
    let highlightPulse: Bool
    let contextMenuBuilder: (() -> NSMenu?)?
    let onActivate: () -> Void

    @Environment(ProjectStore.self) var projectStore
    @Environment(EnvironmentState.self) var environmentState
    @State var isHeaderHovering = false
    
    private var depth: Int {
        max(0, outlineLevel)
    }

    private var leadingAlignmentCompensation: CGFloat {
        switch node.row {
        case .topSpacer:
            0
        case .server, .pendingConnection, .databasesFolder, .serverFolder:
            0
        default:
            -(SidebarRowConstants.rowOuterHorizontalPadding + SpacingTokens.xxxs)
        }
    }

    /// Leading padding for the Finder-style section label so it aligns with
    /// the row's icon column at the same indent depth. Indent step + chevron
    /// column + outer padding.
    private var sectionLabelLeadingPadding: CGFloat {
        let indentSpace = CGFloat(depth) * SidebarRowConstants.indentStep
        return indentSpace
            + SidebarRowConstants.chevronWidth
            + SidebarRowConstants.iconTextSpacing
            + SidebarRowConstants.rowLeadingPadding
            + SidebarRowConstants.rowOuterHorizontalPadding
            + abs(leadingAlignmentCompensation)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let sectionTitle = node.row.groupSectionTitle {
                // Finder-style section label — title case (not uppercase),
                // 12pt semibold in secondary color, anchored to the sidebar's
                // left edge (not aligned with row icons). Same treatment as
                // Finder's "Favorites" / "Locations" / "Tags".
                Text(sectionTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .padding(.leading, SpacingTokens.sm) // 12pt from sidebar edge
                    .padding(.top, 10)
                    .padding(.bottom, 4)
            }
            rowBody
        }
            .padding(.leading, leadingAlignmentCompensation)
            .overlay {
                if shouldShowHighlightOverlay {
                    StatusWaveOverlay(
                        color: ColorTokens.Status.success,
                        cornerRadius: SidebarRowConstants.hoverCornerRadius,
                        trigger: highlightPulse
                    )
                    .clipShape(RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous))
                    .allowsHitTesting(false)
                }
            }
            .modifier(RowLazyContextMenu(menuBuilder: contextMenuBuilder))
    }

    private var shouldShowHighlightOverlay: Bool {
        guard isHighlighted else { return false }
        switch node.row {
        case .topSpacer, .pendingConnection, .server:
            return false
        default:
            return true
        }
    }

    @ViewBuilder
    private var rowBody: some View {
        switch node.row {
        case .topSpacer(let height):
            Color.clear
                .frame(height: height)
        case .pendingConnection(let pending):
            pendingConnectionRow(pending: pending)
        case .server(let session):
            serverRow(session: session)
        case .databasesFolder(_, let count):
            sectionHeading(title: "Databases", count: count)
        case .database(let session, let database, let isLoading):
            buttonRow {
                SidebarRow(
                    depth: depth,
                    icon: .system("cylinder"),
                    label: database.name,
                    isExpanded: Binding(get: { isExpanded }, set: { _ in onActivate() }),
                    isSelected: isSelected,
                    iconColor: databaseIconColor(database, session: session),
                    labelColor: database.isAccessible ? ColorTokens.Text.primary : ColorTokens.Text.secondary,
                    accentColor: resolvedAccentColor(for: session.connection)
                ) {
                    if !database.isOnline, let state = database.stateDescription {
                        Text(state.uppercased())
                            .font(TypographyTokens.compact)
                            .foregroundStyle(ColorTokens.Text.quaternary)
                    } else if !database.isAccessible {
                        Text("NO ACCESS")
                            .font(TypographyTokens.compact)
                            .foregroundStyle(ColorTokens.Text.quaternary)
                    }
                    if isLoading {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
                .opacity(database.isOnline && database.isAccessible ? 1 : 0.5)
            }
        case .objectGroup(_, _, let type, let count):
            // Empty groups stay (their context menus create objects) but step back: no count,
            // no disclosure chevron, dimmed label and symbol.
            buttonRow {
                SidebarRow(
                    depth: depth,
                    icon: .system(type.systemImage),
                    label: type.pluralDisplayName,
                    isExpanded: count > 0
                        ? Binding(get: { isExpanded }, set: { _ in onActivate() })
                        : nil,
                    iconColor: count > 0
                        ? explorerIconColor(ExplorerSidebarPalette.objectGroupIconColor(for: type))
                        : ColorTokens.Text.quaternary,
                    labelColor: count > 0 ? ColorTokens.Text.primary : ColorTokens.Text.tertiary
                ) {
                    countLabel(count)
                }
            }
        case .object(let session, _, let object):
            buttonRow {
                SidebarRow(
                    depth: depth,
                    icon: .system(objectIconName(object.type)),
                    label: object.fullName,
                    labelText: dimmedSchemaLabel(for: object.fullName),
                    isExpanded: object.columns.isEmpty ? nil : Binding(get: { isExpanded }, set: { _ in onActivate() }),
                    isSelected: isSelected,
                    iconColor: ColorTokens.Sidebar.symbol,
                    accentColor: resolvedAccentColor(for: session.connection)
                ) {
                    if let detail = objectTrailingDetail(object) {
                        Text(detail)
                            .font(SidebarRowConstants.trailingFont)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                            .lineLimit(1)
                    }
                }
            }
        case .column(let column, _, _):
            columnRow(column: column)
        case .serverFolder(_, let kind, let count):
            sectionHeading(title: kind.title, count: count)
        case .databaseFolder(_, _, let kind, let count, let isLoading):
            buttonRow {
                SidebarRow(
                    depth: depth,
                    icon: .system(kind.systemImage),
                    label: kind.title,
                    isExpanded: Binding(get: { isExpanded }, set: { _ in onActivate() }),
                    iconColor: explorerIconColor(ExplorerSidebarPalette.folderIconColor(title: kind.title))
                ) {
                    countLabel(count)
                    if isLoading {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
            }
        case .databaseSubfolder(_, _, let title, let systemImage, let paletteTitle, let count):
            buttonRow {
                SidebarRow(
                    depth: depth,
                    icon: .system(systemImage),
                    label: title,
                    isExpanded: Binding(get: { isExpanded }, set: { _ in onActivate() }),
                    iconColor: explorerIconColor(ExplorerSidebarPalette.folderIconColor(title: paletteTitle))
                ) {
                    countLabel(count)
                }
            }
        case .databaseNamedItem(let session, _, let title, let systemImage, let paletteTitle, let detail):
            buttonRow {
                SidebarRow(
                    depth: depth,
                    icon: .system(systemImage),
                    label: title,
                    isSelected: isSelected,
                    iconColor: explorerIconColor(ExplorerSidebarPalette.folderIconColor(title: paletteTitle)),
                    accentColor: resolvedAccentColor(for: session.connection)
                ) {
                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(SidebarRowConstants.trailingFont)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                            .lineLimit(1)
                    }
                }
            }
        case .securitySection(_, let kind, let count, let isLoading):
            buttonRow {
                SidebarRow(
                    depth: depth,
                    icon: .system(kind.systemImage),
                    label: kind.title,
                    isExpanded: Binding(get: { isExpanded }, set: { _ in onActivate() }),
                    iconColor: explorerIconColor(ExplorerSidebarPalette.folderIconColor(title: kind.title))
                ) {
                    countLabel(count)
                    if isLoading {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
            }
        case .securityLogin(_, let login):
            SidebarRow(
                depth: depth,
                icon: .system(securityLoginIconName(login)),
                label: login.name,
                iconColor: securityLoginIconColor(login),
                labelColor: login.isDisabled ? ColorTokens.Text.secondary : ColorTokens.Text.primary
            ) {
                Text(login.loginType)
                    .font(SidebarRowConstants.trailingFont)
                    .foregroundStyle(ColorTokens.Text.tertiary)

                if login.isDisabled {
                    Text("Disabled")
                        .font(SidebarRowConstants.trailingFont)
                        .foregroundStyle(ColorTokens.Text.quaternary)
                }
            }
        case .securityServerRole(_, let role):
            SidebarRow(
                depth: depth,
                icon: .system("shield"),
                label: role.name,
                iconColor: explorerIconColor(ExplorerSidebarPalette.folderIconColor(title: "Server Roles"))
            ) {
                if role.isFixed {
                    Text("Fixed")
                        .font(SidebarRowConstants.trailingFont)
                        .foregroundStyle(ColorTokens.Text.quaternary)
                }
            }
        case .securityCredential(_, let credential):
            SidebarRow(
                depth: depth,
                icon: .system("key"),
                label: credential.name,
                iconColor: explorerIconColor(ExplorerSidebarPalette.folderIconColor(title: "Credentials"))
            ) {
                Text(credential.identity)
                    .font(SidebarRowConstants.trailingFont)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .lineLimit(1)
            }
        case .agentJob(_, let job):
            buttonRow {
                SidebarRow(
                    depth: depth,
                    icon: .system("clock"),
                    label: job.name,
                    isSelected: isSelected,
                    iconColor: explorerIconColor(ExplorerSidebarPalette.folderIconColor(title: "Agent Jobs")),
                    accentColor: Color.accentColor
                ) {
                    if let lastOutcome = job.lastOutcome, !lastOutcome.isEmpty {
                        Text(lastOutcome)
                            .font(SidebarRowConstants.trailingFont)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                }
            }
        case .databaseSnapshot(_, let snapshot):
            buttonRow {
                SidebarRow(
                    depth: depth,
                    icon: .system("camera.fill"),
                    label: snapshot.name,
                    isSelected: isSelected,
                    iconColor: explorerIconColor(ExplorerSidebarPalette.folderIconColor(title: "Database Snapshots")),
                    accentColor: Color.accentColor
                ) {
                    Text(snapshot.sourceDatabaseName)
                        .font(SidebarRowConstants.trailingFont)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .lineLimit(1)
                }
            }
        case .linkedServer(_, let server):
            buttonRow {
                SidebarRow(
                    depth: depth,
                    icon: .system("link"),
                    label: server.name,
                    isSelected: isSelected,
                    iconColor: explorerIconColor(ExplorerSidebarPalette.folderIconColor(title: "Linked Servers")),
                    labelColor: server.isDataAccessEnabled ? ColorTokens.Text.primary : ColorTokens.Text.secondary,
                    accentColor: Color.accentColor
                ) {
                    if !server.dataSource.isEmpty {
                        Text(server.dataSource)
                            .font(SidebarRowConstants.trailingFont)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                            .lineLimit(1)
                    }
                }
            }
        case .ssisFolder(_, let folder):
            buttonRow {
                SidebarRow(
                    depth: depth,
                    icon: .system("folder"),
                    label: folder.name,
                    isSelected: isSelected,
                    iconColor: explorerIconColor(ExplorerSidebarPalette.folderIconColor(title: "Integration Services Catalogs")),
                    accentColor: Color.accentColor
                )
            }
        case .serverTrigger(_, let trigger):
            buttonRow {
                SidebarRow(
                    depth: depth,
                    icon: .system("bolt"),
                    label: trigger.name,
                    isSelected: isSelected,
                    iconColor: explorerIconColor(ExplorerSidebarPalette.folderIconColor(title: "Server Triggers")),
                    labelColor: trigger.isDisabled ? ColorTokens.Text.tertiary : ColorTokens.Text.primary,
                    accentColor: Color.accentColor
                ) {
                    if trigger.isDisabled {
                        Text("Disabled")
                            .font(SidebarRowConstants.trailingFont)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                }
            }
        case .action(_, let action, _):
            buttonRow {
                SidebarRow(
                    depth: depth,
                    icon: .system(action.systemImage),
                    label: action.title,
                    isSelected: isSelected,
                    iconColor: explorerIconColor(ExplorerSidebarPalette.folderIconColor(title: action.title)),
                    accentColor: Color.accentColor
                )
            }
        case .infoLeaf(let title, let systemImage, let paletteTitle, _):
            SidebarRow(
                depth: depth,
                icon: .system(systemImage),
                label: title,
                iconColor: explorerIconColor(ExplorerSidebarPalette.folderIconColor(title: paletteTitle)),
                labelColor: ColorTokens.Text.secondary,
                labelFont: TypographyTokens.detail
            )
        case .loading(let title, _):
            // Shimmer rows at the child indent (plan T4); the real rows crossfade in over them.
            ShimmerPlaceholderRows(
                count: LayoutTokens.Shimmer.explorerRowCount,
                rowHeight: ObjectBrowserOutlineView.baseRowHeight(for: projectStore.globalSettings.sidebarDensity),
                leadingInset: CGFloat(depth) * SidebarRowConstants.indentStep
                    + SidebarRowConstants.chevronWidth
                    + SidebarRowConstants.rowLeadingPadding,
                accessibilityLabel: title.trimmingCharacters(in: CharacterSet(charactersIn: "…."))
            )
        case .message(let title, let systemImage, _):
            SidebarRow(
                depth: depth,
                icon: .system(systemImage),
                label: title,
                iconColor: ColorTokens.Status.warning,
                labelColor: ColorTokens.Text.secondary,
                labelFont: TypographyTokens.detail
            )
        }
    }

    @ViewBuilder
    private func columnRow(column: ColumnInfo) -> some View {
        let typeLabel = Text(EchoFormatters.abbreviatedSQLType(column.dataType))
            .font(SidebarRowConstants.trailingFont)
            .foregroundStyle(ColorTokens.Text.tertiary)
            .lineLimit(1)

        if column.isPrimaryKey {
            SidebarRow(depth: depth, icon: .system("key.fill"), label: column.name, iconColor: Color.orange) {
                typeLabel
            }
        } else if column.foreignKey != nil {
            SidebarRow(depth: depth, icon: .system("arrow.turn.down.right"), label: column.name, iconColor: ColorTokens.Status.info) {
                typeLabel
            }
        } else {
            SidebarRow(depth: depth, icon: .none, label: column.name) {
                typeLabel
            }
        }
    }

    private func serverRow(session: ConnectionSession) -> some View {
        Button(action: onActivate) {
            connectionSectionHeader(session: session, showsDisclosure: true)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(serverSubtitle(session))
        .overlay {
            if isHighlighted {
                StatusWaveOverlay(
                    color: ColorTokens.Status.success,
                    cornerRadius: SidebarRowConstants.hoverCornerRadius,
                    trigger: highlightPulse
                )
            }
        }
    }

    private func pendingConnectionRow(pending: PendingConnection) -> some View {
        let connection = pending.connection
        return ObjectBrowserPendingConnectionRow(
            pending: pending,
            displayName: serverDisplayName(connection),
            onRetry: {
                environmentState.retryPendingConnection(for: connection.id)
            }
        )
    }

    private func securityLoginIconName(
        _ login: ObjectBrowserSidebarViewModel.SecurityLoginItem
    ) -> String {
        if login.loginType == "Group Role" {
            return "person.2.circle"
        }
        return login.isDisabled ? "person.crop.circle.badge.xmark" : "person.crop.circle"
    }

    private func securityLoginIconColor(
        _ login: ObjectBrowserSidebarViewModel.SecurityLoginItem
    ) -> Color {
        if login.isDisabled {
            return ColorTokens.Text.quaternary
        }
        let title: String = if login.loginType == "Group Role" {
            "Group Roles"
        } else if login.loginType.contains("Login") || login.loginType.contains("Superuser") {
            "Login Roles"
        } else {
            "Logins"
        }
        return explorerIconColor(ExplorerSidebarPalette.folderIconColor(title: title))
    }

    private func buttonRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        Button(action: onActivate) {
            content()
        }
        .buttonStyle(.plain)
            .animation(.snappy(duration: 0.18, extraBounce: 0), value: isExpanded)
    }
}

private struct RowLazyContextMenu: ViewModifier {
    let menuBuilder: (() -> NSMenu?)?

    func body(content: Content) -> some View {
        if let menuBuilder {
            content.lazyContextMenu {
                menuBuilder() ?? NSMenu()
            }
        } else {
            content
        }
    }
}
