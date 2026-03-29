import SwiftUI
import AppKit

struct SchemaDiffView: View {
    @Bindable var viewModel: SchemaDiffViewModel
    @Bindable var panelState: BottomPanelState
    @Environment(TabStore.self) private var tabStore
    @Environment(EnvironmentState.self) private var environmentState

    var body: some View {
        MaintenanceTabFrame(
            panelState: panelState,
            connectionText: connectionText,
            isInitialized: viewModel.isInitialized,
            statusBubble: statusBubble
        ) {
            toolbarContent
        } content: {
            diffContent
        }
        .task { await viewModel.initialize() }
    }

    private var connectionText: String {
        let connText = tabStore.activeTab?.connection.connectionName ?? "Server"
        let db = tabStore.activeTab?.activeDatabaseName
        return db.map { "\(connText) \u{2022} \($0)" } ?? connText
    }

    private var statusBubble: BottomPanelStatusBarConfiguration.StatusBubble? {
        if viewModel.isComparing {
            return .init(label: "Comparing\u{2026}", tint: .blue, isPulsing: true)
        }
        return nil
    }

    // MARK: - Toolbar

    private var toolbarContent: some View {
        HStack(spacing: SpacingTokens.sm) {
            Picker("Source", selection: $viewModel.sourceSchema) {
                ForEach(viewModel.availableSchemas, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 160)

            Image(systemName: "arrow.right")
                .foregroundStyle(ColorTokens.Text.secondary)

            Picker("Target", selection: $viewModel.targetSchema) {
                ForEach(viewModel.availableSchemas, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 160)

            if viewModel.canCompare {
                Button("Compare") { Task { await viewModel.compare() } }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            } else {
                Button("Compare") {}
                    .buttonStyle(.bordered)
                    .disabled(true)
                    .controlSize(.small)
            }

            Spacer()

            if !viewModel.diffs.isEmpty {
                TextField("", text: $viewModel.searchText, prompt: Text("Filter objects"))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 180)

                Text(viewModel.statusSummary)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)

                objectTypePicker
                filterPicker

                Button("Copy Migration SQL") {
                    let sql = viewModel.generateMigrationSQLForFilteredDiffs()
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(sql, forType: .string)
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.generateMigrationSQLForFilteredDiffs().isEmpty)

                Button("Export Migration SQL") {
                    exportMigrationSQL()
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.generateMigrationSQLForFilteredDiffs().isEmpty)

                Button("Open Migration SQL") {
                    openMigrationSQLInQueryTab()
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.generateMigrationSQLForFilteredDiffs().isEmpty)
            }
        }
    }

    private var filterPicker: some View {
        Picker("Filter", selection: $viewModel.filterStatus) {
            Text("All").tag(nil as SchemaDiffStatus?)
            Divider()
            ForEach(SchemaDiffStatus.allCases, id: \.self) { status in
                Label(status.rawValue, systemImage: status.icon).tag(status as SchemaDiffStatus?)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: 120)
    }

    private var objectTypePicker: some View {
        Picker("Object Type", selection: $viewModel.filterObjectType) {
            Text("All Types").tag(nil as String?)
            Divider()
            ForEach(viewModel.availableObjectTypes, id: \.self) { objectType in
                Text(objectType).tag(objectType as String?)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: 140)
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
            HSplitView {
                diffTable
                    .frame(minWidth: 300)
                SchemaDiffDetailView(viewModel: viewModel)
                    .frame(minWidth: 300, idealWidth: 400)
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
