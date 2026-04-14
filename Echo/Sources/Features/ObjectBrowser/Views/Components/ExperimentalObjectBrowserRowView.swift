import SwiftUI
import AppKit
import SQLServerKit

struct ExperimentalObjectBrowserRowView: View {
    let node: ExperimentalObjectBrowserNode
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
    
    private var depth: Int {
        max(0, outlineLevel)
    }

    private var leadingAlignmentCompensation: CGFloat {
        switch node.row {
        case .topSpacer:
            0
        case .server:
            -(SidebarRowConstants.rowOuterHorizontalPadding + SpacingTokens.xs)
        case .pendingConnection:
            -(SidebarRowConstants.rowOuterHorizontalPadding + SpacingTokens.xs)
        default:
            -(SidebarRowConstants.rowOuterHorizontalPadding + SpacingTokens.xxxs)
        }
    }

    var body: some View {
        rowBody
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
            buttonRow {
                SidebarRow(
                    depth: depth,
                    icon: .system("cylinder"),
                    label: "Databases",
                    isExpanded: Binding(get: { isExpanded }, set: { _ in onActivate() }),
                    iconColor: ExplorerSidebarPalette.folderIconColor(
                        title: "Databases",
                        colored: projectStore.globalSettings.sidebarIconColorMode == .colorful
                    )
                ) {
                    Text("\(count)")
                        .font(SidebarRowConstants.trailingFont)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
        case .database(let session, let database, let isLoading):
            buttonRow {
                SidebarRow(
                    depth: depth,
                    icon: .system("internaldrive"),
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
            buttonRow {
                SidebarRow(
                    depth: depth,
                    icon: .system(type.systemImage),
                    label: type.pluralDisplayName,
                    isExpanded: Binding(get: { isExpanded }, set: { _ in onActivate() }),
                    iconColor: ExplorerSidebarPalette.objectGroupIconColor(
                        for: type,
                        colored: projectStore.globalSettings.sidebarIconColorMode == .colorful
                    )
                ) {
                    Text("\(count)")
                        .font(SidebarRowConstants.trailingFont)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
        case .object(let session, _, let object):
            buttonRow {
                SidebarRow(
                    depth: depth,
                    icon: .system(objectIconName(object.type)),
                    label: object.fullName,
                    subtitle: objectSubtitle(object),
                    isSelected: isSelected,
                    iconColor: ExplorerSidebarPalette.objectGroupIconColor(
                        for: object.type,
                        colored: projectStore.globalSettings.sidebarIconColorMode == .colorful
                    ),
                    accentColor: resolvedAccentColor(for: session.connection)
                )
            }
        case .serverFolder(_, let kind, let count):
            buttonRow {
                SidebarRow(
                    depth: depth,
                    icon: .system(kind.systemImage),
                    label: kind.title,
                    isExpanded: Binding(get: { isExpanded }, set: { _ in onActivate() }),
                    iconColor: ExplorerSidebarPalette.folderIconColor(
                        title: kind.title,
                        colored: projectStore.globalSettings.sidebarIconColorMode == .colorful
                    )
                ) {
                    if let count {
                        Text("\(count)")
                            .font(SidebarRowConstants.trailingFont)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                }
            }
        case .databaseFolder(_, _, let kind, let count, let isLoading):
            buttonRow {
                SidebarRow(
                    depth: depth,
                    icon: .system(kind.systemImage),
                    label: kind.title,
                    isExpanded: Binding(get: { isExpanded }, set: { _ in onActivate() }),
                    iconColor: ExplorerSidebarPalette.folderIconColor(
                        title: kind.title,
                        colored: projectStore.globalSettings.sidebarIconColorMode == .colorful
                    )
                ) {
                    if let count {
                        Text("\(count)")
                            .font(SidebarRowConstants.trailingFont)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
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
                    iconColor: ExplorerSidebarPalette.folderIconColor(
                        title: paletteTitle,
                        colored: projectStore.globalSettings.sidebarIconColorMode == .colorful
                    )
                ) {
                    if let count {
                        Text("\(count)")
                            .font(SidebarRowConstants.trailingFont)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                }
            }
        case .databaseNamedItem(let session, _, let title, let systemImage, let paletteTitle, let detail):
            buttonRow {
                SidebarRow(
                    depth: depth,
                    icon: .system(systemImage),
                    label: title,
                    isSelected: isSelected,
                    iconColor: ExplorerSidebarPalette.folderIconColor(
                        title: paletteTitle,
                        colored: projectStore.globalSettings.sidebarIconColorMode == .colorful
                    ),
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
                    iconColor: ExplorerSidebarPalette.folderIconColor(
                        title: kind.title,
                        colored: projectStore.globalSettings.sidebarIconColorMode == .colorful
                    )
                ) {
                    Text("\(count)")
                        .font(SidebarRowConstants.trailingFont)
                        .foregroundStyle(ColorTokens.Text.tertiary)
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
                iconColor: ExplorerSidebarPalette.folderIconColor(
                    title: "Server Roles",
                    colored: projectStore.globalSettings.sidebarIconColorMode == .colorful
                )
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
                iconColor: ExplorerSidebarPalette.folderIconColor(
                    title: "Credentials",
                    colored: projectStore.globalSettings.sidebarIconColorMode == .colorful
                )
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
                    iconColor: ExplorerSidebarPalette.folderIconColor(
                        title: "Agent Jobs",
                        colored: projectStore.globalSettings.sidebarIconColorMode == .colorful
                    ),
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
                    iconColor: ExplorerSidebarPalette.folderIconColor(
                        title: "Database Snapshots",
                        colored: projectStore.globalSettings.sidebarIconColorMode == .colorful
                    ),
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
                    iconColor: ExplorerSidebarPalette.folderIconColor(
                        title: "Linked Servers",
                        colored: projectStore.globalSettings.sidebarIconColorMode == .colorful
                    ),
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
                    iconColor: ExplorerSidebarPalette.folderIconColor(
                        title: "Integration Services Catalogs",
                        colored: projectStore.globalSettings.sidebarIconColorMode == .colorful
                    ),
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
                    iconColor: ExplorerSidebarPalette.folderIconColor(
                        title: "Server Triggers",
                        colored: projectStore.globalSettings.sidebarIconColorMode == .colorful
                    ),
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
                    iconColor: ExplorerSidebarPalette.folderIconColor(
                        title: action.title,
                        colored: projectStore.globalSettings.sidebarIconColorMode == .colorful
                    ),
                    accentColor: Color.accentColor
                )
            }
        case .infoLeaf(let title, let systemImage, let paletteTitle, _):
            SidebarRow(
                depth: depth,
                icon: .system(systemImage),
                label: title,
                iconColor: ExplorerSidebarPalette.folderIconColor(
                    title: paletteTitle,
                    colored: projectStore.globalSettings.sidebarIconColorMode == .colorful
                ),
                labelColor: ColorTokens.Text.secondary,
                labelFont: TypographyTokens.detail
            )
        case .loading(let title, _):
            SidebarRow(
                depth: depth,
                icon: .none,
                label: title,
                labelColor: ColorTokens.Text.tertiary,
                labelFont: TypographyTokens.detail
            ) {
                ProgressView()
                    .controlSize(.mini)
            }
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

    private func serverRow(session: ConnectionSession) -> some View {
        SidebarConnectionHeader(
            connectionName: serverDisplayName(session),
            subtitle: serverSubtitle(session),
            databaseType: session.connection.databaseType,
            connectionColor: resolvedAccentColor(for: session.connection),
            isExpanded: Binding(get: { isExpanded }, set: { _ in onActivate() }),
            isColorful: projectStore.globalSettings.sidebarIconColorMode == .colorful,
            isSecure: session.connection.useTLS,
            connectionState: session.connectionState,
            onAction: onActivate,
            iconScale: 1,
            iconFrameScale: 1.58,
            iconGlyphScale: 1.55,
            leadingPaddingAdjustment: -SpacingTokens.xxs2,
            statusPresentation: .none,
            labelFont: TypographyTokens.standard.weight(.medium)
        )
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
        let connectionState: ConnectionState = switch pending.phase {
        case .connecting:
            .connecting
        case .failed(let message):
            .error(.connectionFailed(message))
        }

        let trailingAccessory: SidebarConnectionHeader.TrailingAccessory = switch pending.phase {
        case .connecting:
            .spinner
        case .failed:
            .retryButton({
                environmentState.retryPendingConnection(for: connection.id)
            })
        }

        return SidebarConnectionHeader(
            connectionName: serverDisplayName(connection),
            subtitle: connection.databaseType.displayName,
            databaseType: connection.databaseType,
            connectionColor: resolvedAccentColor(for: connection),
            isExpanded: .constant(false),
            isColorful: projectStore.globalSettings.sidebarIconColorMode == .colorful,
            isSecure: connection.useTLS,
            connectionState: connectionState,
            onAction: {},
            trailingAccessory: trailingAccessory,
            iconScale: 1,
            iconFrameScale: 1.58,
            iconGlyphScale: 1.55,
            leadingPaddingAdjustment: -SpacingTokens.xxs2,
            statusPresentation: .none,
            labelFont: TypographyTokens.standard.weight(.medium)
        )
        .background {
            switch pending.phase {
            case .connecting:
                StatusWaveOverlay(
                    color: ColorTokens.accent,
                    cornerRadius: SidebarRowConstants.hoverCornerRadius,
                    continuous: true
                )
                .clipShape(RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous))
                .allowsHitTesting(false)
            case .failed:
                StatusWaveOverlay(
                    color: ColorTokens.Status.error,
                    cornerRadius: SidebarRowConstants.hoverCornerRadius,
                    trigger: true
                )
                .clipShape(RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous))
                .allowsHitTesting(false)
            }
        }
    }

    private func securityLoginIconName(
        _ login: ExperimentalObjectBrowserSidebarViewModel.SecurityLoginItem
    ) -> String {
        if login.loginType == "Group Role" {
            return "person.2.circle"
        }
        return login.isDisabled ? "person.crop.circle.badge.xmark" : "person.crop.circle"
    }

    private func securityLoginIconColor(
        _ login: ExperimentalObjectBrowserSidebarViewModel.SecurityLoginItem
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
        return ExplorerSidebarPalette.folderIconColor(
            title: title,
            colored: projectStore.globalSettings.sidebarIconColorMode == .colorful
        )
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
