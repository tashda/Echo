import SwiftUI

struct DatabaseObjectRow: View, Equatable {
    let object: SchemaObjectInfo
    let displayName: String
    let connection: SavedConnection
    let databaseName: String?
    let showColumns: Bool
    @Binding var isExpanded: Bool
    let isPinned: Bool
    let onTogglePin: () -> Void
    let onTriggerTableTap: ((String) -> Void)?

    @Environment(ProjectStore.self) internal var projectStore
    @Environment(ConnectionStore.self) internal var connectionStore
    @Environment(EnvironmentState.self) internal var environmentState
    @Environment(ObjectBrowserSidebarViewModel.self) internal var viewModel

    @State internal var hoveredColumnID: String?
    @State internal var showDropAlert = false
    @State internal var showTruncateAlert = false
    @State internal var showRenameAlert = false
    @State internal var renameText = ""
    @State internal var pendingDropIncludeIfExists = false
    @State internal var showBulkImportSheet = false

    private var canExpand: Bool {
        showColumns && !object.columns.isEmpty
    }

    internal var accentColor: Color {
        projectStore.globalSettings.accentColorSource == .connection ? connection.color : ColorTokens.accent
    }

    private var iconName: String {
        switch object.type {
        case .table: return "tablecells"
        case .view: return "eye"
        case .materializedView: return "eye.fill"
        case .function: return "function"
        case .trigger: return "bolt.fill"
        case .procedure: return "terminal"
        case .extension: return "puzzlepiece.fill"
        }
    }

    private var iconColor: Color {
        ExplorerSidebarPalette.objectGroupIconColor(for: object.type, colored: projectStore.globalSettings.sidebarColoredIcons)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            rowContent

            if isExpanded && canExpand {
                columnsList
            }
        }
        .buttonStyle(.plain)
        .focusable(false)
        .alert("Drop \(objectTypeDisplayName())?", isPresented: $showDropAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Drop", role: .destructive) { performDrop(includeIfExists: pendingDropIncludeIfExists) }
        } message: {
            Text("Are you sure you want to drop the \(objectTypeDisplayName().lowercased()) \(object.fullName)? This action cannot be undone.")
        }
        .alert("Truncate \(objectTypeDisplayName())?", isPresented: $showTruncateAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Truncate", role: .destructive) { performTruncate() }
        } message: {
            Text("Are you sure you want to truncate the \(objectTypeDisplayName().lowercased()) \(object.fullName)? This action cannot be undone.")
        }
        .alert("Rename \(objectTypeDisplayName())", isPresented: $showRenameAlert) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") { performRename() }
        } message: {
            Text("Enter a new name for the \(objectTypeDisplayName().lowercased()) \(object.fullName).")
        }
        .sheet(isPresented: $showBulkImportSheet) {
            if let session = environmentState.sessionGroup.sessionForConnection(connection.id) {
                BulkImportSheet(
                    viewModel: BulkImportViewModel(
                        session: session.session,
                        connectionSession: session,
                        schema: object.schema.isEmpty ? "dbo" : object.schema,
                        tableName: object.name
                    ),
                    onDismiss: { showBulkImportSheet = false }
                )
            }
        }
    }

    static func == (lhs: DatabaseObjectRow, rhs: DatabaseObjectRow) -> Bool {
        lhs.object.id == rhs.object.id
            && lhs.displayName == rhs.displayName
            && lhs.databaseName == rhs.databaseName
            && lhs.showColumns == rhs.showColumns
            && lhs.isExpanded == rhs.isExpanded
            && lhs.isPinned == rhs.isPinned
    }

    private var isSelected: Bool {
        viewModel.selectedObjectID == object.id
    }

    private var rowContent: some View {
        ExplorerSidebarRowChrome(isSelected: isSelected, accentColor: accentColor, style: .plain) {
            HStack(alignment: .center, spacing: SidebarRowConstants.iconTextSpacing) {
                if canExpand {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(SidebarRowConstants.chevronFont)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .frame(width: SidebarRowConstants.chevronWidth)
                } else {
                    Spacer().frame(width: SidebarRowConstants.chevronWidth)
                }

                Image(systemName: iconName)
                    .font(SidebarRowConstants.iconFont)
                    .foregroundStyle(iconColor)
                    .frame(width: SidebarRowConstants.iconFrame)

                VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                    Text(displayName)
                        .font(TypographyTokens.standard)
                        .foregroundStyle(ColorTokens.Text.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if object.type == .trigger, let table = object.triggerTable, !table.isEmpty {
                        Button {
                            onTriggerTableTap?(table)
                        } label: {
                            HStack(spacing: SpacingTokens.xxxs) {
                                Text("on")
                                    .font(TypographyTokens.label)
                                    .foregroundStyle(ColorTokens.Text.tertiary)
                                Text(table)
                                    .font(TypographyTokens.label)
                                    .foregroundStyle(ColorTokens.Text.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if let comment = object.comment?.trimmingCharacters(in: .whitespacesAndNewlines), !comment.isEmpty {
                        Text(comment)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .help(comment)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, SidebarRowConstants.rowHorizontalPadding)
            .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
            .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
            .contentShape(Rectangle())
        }
        .onTapGesture {
            viewModel.selectedObjectID = object.id
            guard canExpand else { return }
            isExpanded.toggle()
        }
        .contextMenu { contextMenuContent }
    }
}
