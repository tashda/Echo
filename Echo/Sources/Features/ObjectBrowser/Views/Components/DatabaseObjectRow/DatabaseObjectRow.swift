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
    @State internal var showGenerateScriptsWizard = false

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
        case .sequence: return "number"
        case .type: return "t.square"
        case .synonym: return "arrow.triangle.branch"
        }
    }

    private var iconColor: Color {
        ExplorerSidebarPalette.objectGroupIconColor(for: object.type, colored: projectStore.globalSettings.sidebarIconColorMode == .colorful)
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
                    viewModel: {
                        let defaultSchema: String
                        switch connection.databaseType {
                        case .microsoftSQL: defaultSchema = object.schema.isEmpty ? "dbo" : object.schema
                        case .postgresql: defaultSchema = object.schema.isEmpty ? "public" : object.schema
                        case .sqlite, .mysql: defaultSchema = object.schema
                        }
                        let vm = BulkImportViewModel(
                            session: session.session,
                            connectionSession: session,
                            databaseType: connection.databaseType,
                            schema: defaultSchema,
                            tableName: object.name
                        )
                        vm.activityEngine = AppDirector.shared.activityEngine
                        return vm
                    }(),
                    onDismiss: { showBulkImportSheet = false }
                )
            }
        }
        .sheet(isPresented: $showGenerateScriptsWizard) {
            if let session = environmentState.sessionGroup.sessionForConnection(connection.id) {
                GenerateScriptsWizardView(
                    viewModel: GenerateScriptsWizardViewModel(session: session.session)
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
            ) {
                tableFeatureBadges
            }
        }
        .contextMenu { contextMenuContent }
    }

    @ViewBuilder
    private var tableFeatureBadges: some View {
        if object.type == .table {
            HStack(spacing: SpacingTokens.xxs) {
                if object.isSystemVersioned == true {
                    Text("Temporal")
                        .font(TypographyTokens.detail.weight(.medium))
                        .foregroundStyle(ColorTokens.Status.info.opacity(0.8))
                        .padding(.horizontal, SpacingTokens.xxs2)
                        .padding(.vertical, 1)
                        .background(ColorTokens.Status.info.opacity(0.1), in: Capsule())
                }
                if object.isHistoryTable == true {
                    Text("History")
                        .font(TypographyTokens.detail.weight(.medium))
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .padding(.horizontal, SpacingTokens.xxs2)
                        .padding(.vertical, 1)
                        .background(ColorTokens.Text.tertiary.opacity(0.1), in: Capsule())
                }
                if object.isMemoryOptimized == true {
                    Text("In-Memory")
                        .font(TypographyTokens.detail.weight(.medium))
                        .foregroundStyle(ColorTokens.Status.warning.opacity(0.8))
                        .padding(.horizontal, SpacingTokens.xxs2)
                        .padding(.vertical, 1)
                        .background(ColorTokens.Status.warning.opacity(0.1), in: Capsule())
                }
            }
        }
    }
}
