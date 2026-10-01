import SwiftUI
import AppKit

struct SchemaDiffView: View {
    @Bindable var viewModel: SchemaDiffViewModel
    @Bindable var panelState: BottomPanelState
    @Environment(TabStore.self) private var tabStore
    @Environment(\.workspaceTab) private var hostTab
    @Environment(EnvironmentState.self) private var environmentState

    @State private var diffListFraction: CGFloat = 0.45

    var body: some View {
        MaintenanceTabFrame(
            panelState: panelState,
            serverName: connectionText,
            isInitialized: viewModel.isInitialized,
            statusBubble: statusBubble
        ) {
            diffContent
        }
        .toolTabHeaderControls { headerControls }
        .toolTabHeaderDetail(viewModel.diffs.isEmpty ? nil : viewModel.statusSummary)
        .task { await viewModel.initialize() }
    }

    private var connectionText: String {
        let connText = hostTab?.connection.connectionName ?? "Server"
        let db = hostTab?.activeDatabaseName
        return db.map { "\(connText) \u{2022} \($0)" } ?? connText
    }

    private var statusBubble: BottomPanelStatusBarConfiguration.StatusBubble? {
        if viewModel.isComparing {
            return .init(label: "Comparing\u{2026}", tint: .blue, isPulsing: true)
        }
        return nil
    }

    // MARK: - Header line

    /// Source → target and Compare on the tool's header line, with the filters and the migration
    /// script's actions once there is a comparison (round 37.2, 37.3).
    @ViewBuilder
    private var headerControls: some View {
        if !viewModel.diffs.isEmpty {
            ToolTabSearchField(prompt: "Filter objects", text: $viewModel.searchText)
            objectTypePicker
            filterPicker
            ToolTabActionGroup {
                let hasSQL = !viewModel.generateMigrationSQLForFilteredDiffs().isEmpty
                ToolTabActionMenu(title: "Migration SQL and Report", systemImage: "square.and.arrow.up") {
                    Button("Open Migration SQL") { openMigrationSQLInQueryTab() }.disabled(!hasSQL)
                    Button("Copy Migration SQL") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(viewModel.generateMigrationSQLForFilteredDiffs(), forType: .string)
                    }
                    .disabled(!hasSQL)
                    Button("Export Migration SQL") { exportMigrationSQL() }.disabled(!hasSQL)
                    Divider()
                    Button("Export Report as HTML") { exportComparisonReport(as: .html) }
                    Button("Export Report as Markdown") { exportComparisonReport(as: .markdown) }
                    Button("Export Report as Text") { exportComparisonReport(as: .text) }
                }
            }
        }
        ToolTabPickerPill(title: "Source", systemImage: "square.stack.3d.up", selection: $viewModel.sourceSchema,
                          options: viewModel.availableSchemas, label: { $0 })
        Image(systemName: "arrow.right").foregroundStyle(ColorTokens.Text.secondary).accessibilityHidden(true)
        ToolTabPickerPill(title: "Target", systemImage: "square.stack.3d.down.right", selection: $viewModel.targetSchema,
                          options: viewModel.availableSchemas, label: { $0 })
        ToolTabPrimaryButton(title: viewModel.isComparing ? "Comparing" : "Compare", systemImage: "arrow.left.arrow.right",
                             isDisabled: !viewModel.canCompare || viewModel.isComparing) {
            Task { await viewModel.compare() }
        }
    }

    private var filterPicker: some View {
        ToolTabPickerPill(title: "Status", systemImage: "line.3.horizontal.decrease", selection: $viewModel.filterStatus,
                          options: [nil] + SchemaDiffStatus.allCases.map(Optional.some),
                          label: { $0?.rawValue ?? "All Changes" })
    }

    private var objectTypePicker: some View {
        ToolTabPickerPill(title: "Object Type", systemImage: "square.grid.2x2", selection: $viewModel.filterObjectType,
                          options: [nil] + viewModel.availableObjectTypes.map(Optional.some),
                          label: { $0 ?? "All Types" })
    }

    // MARK: - Content

    @ViewBuilder
    private var diffContent: some View {
        if viewModel.diffs.isEmpty && !viewModel.isComparing {
            ContentUnavailableView(
                "Schema Diff",
                systemImage: "doc.on.doc",
                description: Text("Select source and target schemas, then click Compare to see differences.")
            )
        } else {
            // TT1: the diff list and the selected object's detail are two cards.
            CardSplitView(axis: .horizontal, fraction: $diffListFraction, minFraction: 0.25) {
                diffTable
            } second: {
                SchemaDiffDetailView(viewModel: viewModel)
            }
        }
    }

    private var diffTable: some View {
        Table(viewModel.filteredDiffs, selection: $viewModel.selectedDiffID) {
            TableColumn("Status") { item in
                Label(item.status.rawValue, systemImage: item.status.icon)
                    .font(TypographyTokens.Table.status)
                    .foregroundStyle(statusColor(for: item.status))
            }
            .width(min: 80, ideal: 100, max: 120)

            TableColumn("Type") { item in
                Text(item.objectType)
                    .font(TypographyTokens.Table.category)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 60, ideal: 90, max: 120)

            TableColumn("Name") { item in
                Text(item.objectName)
                    .font(TypographyTokens.Table.name)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: SchemaDiffItem.ID.self) { ids in
            if let id = ids.first, let item = viewModel.diffs.first(where: { $0.id == id }) {
                Button("Copy Migration SQL") {
                    let sql = viewModel.generateMigrationSQL(for: item)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(sql, forType: .string)
                }
            }
        }
    }

    private func statusColor(for status: SchemaDiffStatus) -> Color {
        switch status {
        case .added: return ColorTokens.Status.success
        case .removed: return ColorTokens.Status.error
        case .modified: return ColorTokens.Status.warning
        case .identical: return ColorTokens.Text.tertiary
        }
    }

    private func openMigrationSQLInQueryTab() {
        let sql = viewModel.generateMigrationSQLForFilteredDiffs()
        guard !sql.isEmpty,
              let session = environmentState.sessionGroup.activeSessions.first(where: { $0.id == viewModel.connectionSessionID }) else {
            return
        }

        let database = session.connection.databaseType == .mysql ? viewModel.targetSchema : nil
        environmentState.openQueryTab(for: session, presetQuery: sql, database: database)
    }
}
