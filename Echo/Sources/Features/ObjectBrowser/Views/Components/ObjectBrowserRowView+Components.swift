import SwiftUI

/// The row kinds, each drawn with `SidebarRow` in the tree's style.
extension ObjectBrowserRowView {
    func databaseRow(_ database: DatabaseInfo, session: ConnectionSession, isLoading: Bool) -> some View {
        buttonRow {
            SidebarRow(
                depth: depth,
                icon: .system("cylinder"),
                label: database.name,
                isExpanded: expansionBinding,
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
    }

    /// A folder inside a server or database. Empty object folders stay (their menus create
    /// objects) but step back: no count, no chevron, dimmed label and symbol.
    func folderRow(_ folder: ExplorerFolder) -> some View {
        let isEmptyObjectFolder = folder.kind.objectType != nil && (folder.count ?? 0) == 0
        return buttonRow {
            SidebarRow(
                depth: depth,
                icon: .system(folder.kind.symbol),
                label: folder.kind.title,
                // An empty folder still opens, to its grey "No views" row (round 30.3, OE0).
                isExpanded: expansionBinding,
                isSelected: isSelected,
                iconColor: isEmptyObjectFolder ? ColorTokens.Text.quaternary : explorerIconColor(folder.kind.role.color),
                labelColor: isEmptyObjectFolder ? ColorTokens.Text.tertiary : ColorTokens.Text.primary,
                accentColor: resolvedAccentColor(for: folder.session.connection),
                // While the folder loads, its spinner takes the count's place.
                count: folder.isLoading ? nil : folder.count
            ) {
                if folder.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
        }
    }

    func objectRow(_ object: SchemaObjectInfo, session: ConnectionSession) -> some View {
        buttonRow {
            SidebarRow(
                depth: depth,
                icon: .system(object.type.systemImage),
                label: object.fullName,
                labelText: dimmedSchemaLabel(for: object.fullName),
                isExpanded: object.columns.isEmpty ? nil : expansionBinding,
                isSelected: isSelected,
                iconColor: ColorTokens.Sidebar.symbol,
                accentColor: resolvedAccentColor(for: session.connection)
            ) {
                if let detail = objectTrailingDetail(object) {
                    trailingDetail(detail)
                }
            }
        }
    }

    /// A loaded item. The loader chose its name, detail, symbol and whether it's dimmed.
    func itemRow(_ row: ExplorerItemRow) -> some View {
        let item = row.item
        return buttonRow {
            SidebarRow(
                depth: depth,
                icon: .system(item.symbol ?? row.kind.symbol),
                label: item.name,
                isSelected: isSelected,
                iconColor: item.isDisabled ? ColorTokens.Text.quaternary : ColorTokens.Text.secondary,
                labelColor: item.isDisabled ? ColorTokens.Text.secondary : ColorTokens.Text.primary,
                accentColor: resolvedAccentColor(for: row.session.connection)
            ) {
                if let detail = item.detail, !detail.isEmpty {
                    trailingDetail(detail)
                }
            }
        }
    }

    func actionRow(_ kind: ExplorerNodeKind, session: ConnectionSession) -> some View {
        buttonRow {
            SidebarRow(
                depth: depth,
                icon: .system(kind.symbol),
                label: kind.title,
                isSelected: isSelected,
                iconColor: explorerIconColor(kind.role.color),
                accentColor: resolvedAccentColor(for: session.connection)
            )
        }
    }

    @ViewBuilder
    func columnRow(column: ColumnInfo) -> some View {
        let typeLabel = trailingDetail(EchoFormatters.abbreviatedSQLType(column.dataType))
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

    func serverRow(session: ConnectionSession) -> some View {
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

    func pendingConnectionRow(pending: PendingConnection) -> some View {
        let connection = pending.connection
        return ObjectBrowserPendingConnectionRow(
            pending: pending,
            displayName: serverDisplayName(connection),
            onRetry: {
                environmentState.retryPendingConnection(for: connection.id)
            }
        )
    }

    private var expansionBinding: Binding<Bool> {
        Binding(get: { isExpanded }, set: { _ in onActivate() })
    }

    private func trailingDetail(_ text: String) -> some View {
        Text(text)
            .font(SidebarRowConstants.trailingFont)
            .foregroundStyle(ColorTokens.Text.tertiary)
            .lineLimit(1)
    }

    private func buttonRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        Button(action: onActivate) {
            content()
        }
        .buttonStyle(.plain)
        // Not a focus stop: the tree has its own selection, and hundreds of focusable rows made
        // SwiftUI's focus walk run on every animation frame.
        .focusable(false)
        // The chevron and the open-folder accent move with the tree's own `expand` curve.
        .animation(motion.expand, value: isExpanded)
    }
}
