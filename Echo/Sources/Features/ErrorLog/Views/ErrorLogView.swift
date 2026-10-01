import SwiftUI
import SQLServerKit

struct ErrorLogView: View {
    @Bindable var viewModel: ErrorLogViewModel
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppState.self) private var appState

    var body: some View {
        // The products are pages in the tab (round 36.2); the archive and search sit on the header
        // line (37.2), Cycle Log and Refresh in the window toolbar (37.5).
        Group {
            if !viewModel.isInitialized {
                TabInitializingPlaceholder(
                    icon: "doc.text.magnifyingglass",
                    title: "Initializing Error Log",
                    subtitle: "Loading log entries"
                )
            } else {
                logContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.Background.primary)
        .tabContentFrame()
        .task { await viewModel.initialLoad() }
        .onChange(of: viewModel.selectedArchive) {
            Task { await viewModel.loadEntries() }
        }
        .toolTabHeaderControls { headerControls }
        // Round 37.5: Cycle Log and Refresh in the window toolbar.
        .tabToolbar(groups: [[
            TabToolbarItem(id: "cycleLog", title: "Cycle Log: archive the current error log and start a new one",
                           symbol: "arrow.triangle.2.circlepath") { [viewModel] in Task { await viewModel.cycleLog() } },
            .refresh(isBusy: viewModel.isLoading) { [viewModel] in Task { await viewModel.refresh() } },
        ]])
    }

    // MARK: - Header line

    private var headerControls: some View {
        Group {
            ToolTabPickerPill(title: "Log", systemImage: "archivebox", selection: $viewModel.selectedArchive,
                              options: archiveNumbers, label: archiveLabel)
            ToolTabSearchField(prompt: "Search log", text: $viewModel.searchText)
        }
    }

    private var archiveNumbers: [Int] {
        let numbers = viewModel.sortedArchives.map(\.archiveNumber)
        return numbers.isEmpty ? [viewModel.selectedArchive] : numbers
    }

    private func archiveLabel(_ number: Int) -> String {
        guard let archive = viewModel.sortedArchives.first(where: { $0.archiveNumber == number }) else { return "Current" }
        return number == 0 ? "Current \u{2014} \(archive.date)" : "Archive #\(number) \u{2014} \(archive.date)"
    }

    // MARK: - Table

    @ViewBuilder
    private var logContent: some View {
        if viewModel.isLoading && viewModel.filteredEntries.isEmpty {
            TabInitializingPlaceholder(
                icon: "doc.text.magnifyingglass",
                title: "Loading Error Log",
                subtitle: "Fetching SQL Server log entries…"
            )
        } else if viewModel.filteredEntries.isEmpty {
            TabContentUnavailableView(
                viewModel.searchText.isEmpty ? "No Log Entries" : "No Results",
                systemImage: "doc.text.magnifyingglass"
            ) {
                Text(viewModel.searchText.isEmpty
                    ? "The selected error log is empty."
                    : "No entries match \u{201c}\(viewModel.searchText)\u{201d}.")
            }
        } else {
            logTable
        }
    }

    private var logTable: some View {
        Table(viewModel.filteredEntries, selection: $viewModel.selectedEntryIDs) {
            TableColumn("Date") { entry in
                Text(entry.logDate ?? "\u{2014}")
                    .font(TypographyTokens.Table.date)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(130)

            TableColumn("Source") { entry in
                Text(entry.processInfo ?? "\u{2014}")
                    .font(TypographyTokens.Table.category)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(80)

            TableColumn("Message") { entry in
                Text(entry.text)
                    .font(TypographyTokens.Table.name)
                    .lineLimit(1)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: SQLServerErrorLogEntry.ID.self) { ids in
            if ids.first != nil {
                Button {
                    appState.showInfoSidebar.toggle()
                } label: {
                    Label("View Details", systemImage: "info.circle")
                }
            }
        } primaryAction: { _ in
            // Double-click: toggle inspector
            if let id = viewModel.selectedEntryIDs.first,
               let entry = viewModel.logEntries.first(where: { $0.id == id }) {
                pushInspector(entry, toggle: true)
            }
        }
        .onChange(of: viewModel.selectedEntryIDs) { _, ids in
            // Single-click: push inspector content (don't toggle visibility)
            if let id = ids.first,
               let entry = viewModel.logEntries.first(where: { $0.id == id }) {
                pushInspector(entry, toggle: false)
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(SpacingTokens.sm)
            }
        }
    }

    // MARK: - Inspector

    private func pushInspector(_ entry: SQLServerErrorLogEntry, toggle: Bool) {
        var fields: [DatabaseObjectInspectorContent.Field] = []
        if let date = entry.logDate {
            fields.append(.init(label: "Date", value: date))
        }
        if let source = entry.processInfo {
            fields.append(.init(label: "Source", value: source))
        }
        fields.append(.init(label: "Message", value: entry.text))

        let content = DatabaseObjectInspectorContent(
            title: entry.processInfo ?? "Log Entry",
            subtitle: entry.logDate ?? "",
            fields: fields
        )

        if toggle {
            environmentState.toggleDataInspector(
                content: .databaseObject(content),
                title: entry.text,
                appState: appState
            )
        } else {
            environmentState.dataInspectorContent = .databaseObject(content)
        }
    }
}
