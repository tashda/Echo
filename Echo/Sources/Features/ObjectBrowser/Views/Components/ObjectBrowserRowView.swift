import SwiftUI
import AppKit

/// One Explorer row. What a row shows comes from its node kind and the loaded data, so this view
/// never switches on a database type.
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
    @Environment(\.explorerDockSectionTitles) var dockSectionTitles

    var depth: Int {
        max(0, outlineLevel)
    }

    var body: some View {
        // Rows are inset equally on both sides (round 16): the 8pt pull to the left, left over
        // from S1's chevron column, made the selection touch the card's left edge only.
        rowBody
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
            // The dock gives each icon its own menu; a row-wide one would cover them.
            .modifier(RowLazyContextMenu(menuBuilder: isDock ? nil : contextMenuBuilder))
    }

    private var isDock: Bool {
        if case .dock = node.row { return true }
        return false
    }

    private var shouldShowHighlightOverlay: Bool {
        guard isHighlighted else { return false }
        switch node.row {
        case .topSpacer, .pendingConnection, .server, .section, .dock:
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
        case .section(let folder):
            sectionHeading(title: folder.kind.title, count: folder.count)
        case .database(let session, let database, let isLoading):
            databaseRow(database, session: session, isLoading: isLoading)
        case .folder(let folder):
            folderRow(folder)
        case .object(let session, _, let object):
            objectRow(object, session: session)
        case .column(let column):
            columnRow(column: column)
        case .item(let row):
            itemRow(row)
        case .action(let session, let kind):
            actionRow(kind, session: session)
        case .placeholder(let title, let kind):
            SidebarRow(
                depth: depth,
                icon: .system(kind?.symbol ?? "tray"),
                label: title,
                iconColor: kind.map { explorerIconColor($0.role.color) } ?? ColorTokens.Text.secondary,
                labelColor: ColorTokens.Text.secondary,
                labelFont: TypographyTokens.detail
            )
        case .loading(let title, .spinnerRow):
            SidebarSpinnerRow(depth: depth, title: title)
        case .loading(let title, .skeleton):
            // Skeleton rows at the child indent (round 16); the real rows fade in over them.
            SkeletonPlaceholderRows(
                count: LayoutTokens.Shimmer.explorerRowCount,
                rowHeight: ObjectBrowserOutlineView.baseRowHeight(for: projectStore.globalSettings.sidebarDensity),
                leadingInset: CGFloat(depth) * SidebarRowConstants.indentStep
                    + SidebarRowConstants.rowOuterHorizontalPadding
                    + SidebarRowConstants.rowLeadingPadding,
                accessibilityLabel: title
            )
        case .dock(let session, let layout, let selectedID):
            ExplorerDockRow(
                connectionID: session.connection.id,
                layout: layout,
                selectedID: selectedID,
                style: projectStore.globalSettings.sidebarDockIconStyle,
                accentColor: resolvedAccentColor(for: session.connection),
                duotoneColor: { $0.mix(with: ColorTokens.Text.secondary, by: ColorTokens.Explorer.colorfulSoftening) }
            )
        case .message(let title, let systemImage):
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
