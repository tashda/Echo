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
        case .materializedView: return "eye"
        case .function: return "function"
        case .trigger: return "bolt"
        case .procedure: return "terminal"
        case .extension: return "puzzlepiece.extension"
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

    private var expandedBinding: Binding<Bool>? {
        guard canExpand else { return nil }
        return $isExpanded
    }

    private var triggerSubtitle: String? {
        guard object.type == .trigger, let table = object.triggerTable, !table.isEmpty else { return nil }
        return "on \(table)"
    }

    private var rowContent: some View {
        Button {
            viewModel.selectedObjectID = object.id
            guard canExpand else { return }
            isExpanded.toggle()
        } label: {
            SidebarRow(
                depth: 3,
                icon: .system(iconName),
                label: displayName,
                subtitle: triggerSubtitle,
                isExpanded: expandedBinding,
                isSelected: isSelected,
                iconColor: iconColor,
                accentColor: accentColor
            )
        }
        .contextMenu { contextMenuContent }
    }
}
