import SwiftUI

struct DatabaseObjectRow: View, Equatable {
    let object: SchemaObjectInfo
    let displayName: String
    let connection: SavedConnection
    let databaseName: String?
    let showColumns: Bool
    @Binding var isExpanded: Bool
    let isPinned: Bool
    let isSelected: Bool
    let accentColor: Color
    let iconColor: Color
    let onTogglePin: () -> Void
    let onTriggerTableTap: ((String) -> Void)?

    @Environment(EnvironmentState.self) internal var environmentState
    @Environment(ObjectBrowserSidebarViewModel.self) internal var viewModel
    @Environment(SidebarSheetState.self) internal var sheetState
    @Environment(ConnectionStore.self) internal var connectionStore
    @Environment(\.openWindow) internal var openWindow

    @State internal var hoveredColumnID: String?
    @State internal var showDropAlert = false
    @State internal var showTruncateAlert = false
    @State internal var showRenameAlert = false
    @State internal var renameText = ""
    @State internal var pendingDropIncludeIfExists = false
    @State internal var showBulkImportSheet = false
    @State internal var showExportSheet = false
    @State internal var showGenerateScriptsWizard = false

    private var canExpand: Bool {
        showColumns && !object.columns.isEmpty
    }

    private var iconName: String {
        switch object.type {
        case .table: return "tablecells"
        case .view: return "eye"
        case .materializedView: return "eye"
        case .function: return "function"
        case .trigger: return "bolt"
        case .procedure: return "terminal"
        case .extension: return "puzzlepiece"
        case .sequence: return "number"
        case .type: return "t.square"
        case .synonym: return "arrow.triangle.branch"
        }
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
        .modifier(DatabaseObjectRowAlerts(
            object: object,
            connection: connection,
            databaseName: databaseName,
            showDropAlert: $showDropAlert,
            showTruncateAlert: $showTruncateAlert,
            showRenameAlert: $showRenameAlert,
            renameText: $renameText,
            pendingDropIncludeIfExists: $pendingDropIncludeIfExists,
            showBulkImportSheet: $showBulkImportSheet,
            showExportSheet: $showExportSheet,
            showGenerateScriptsWizard: $showGenerateScriptsWizard,
            performDrop: { includeIfExists in performDrop(includeIfExists: includeIfExists) },
            performTruncate: { performTruncate() },
            performRename: { performRename() }
        ))
    }

    static func == (lhs: DatabaseObjectRow, rhs: DatabaseObjectRow) -> Bool {
        lhs.object.id == rhs.object.id
            && lhs.displayName == rhs.displayName
            && lhs.databaseName == rhs.databaseName
            && lhs.showColumns == rhs.showColumns
            && lhs.isExpanded == rhs.isExpanded
            && lhs.isPinned == rhs.isPinned
            && lhs.isSelected == rhs.isSelected
            && lhs.accentColor == rhs.accentColor
            && lhs.iconColor == rhs.iconColor
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
