import SwiftUI
import SQLServerKit

struct ErrorLogView: View {
    @Bindable var viewModel: ErrorLogViewModel
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            TabSectionToolbar(sectionPicker: { sectionToolbar }) { archivePicker }
            Divider()

            if !viewModel.isInitialized {
                TabInitializingPlaceholder(
                    icon: "doc.text.magnifyingglass",
                    title: "Initializing Error Log",
                    subtitle: "Loading log entries"
                )
            } else {
                logTable
            }
        }
        .background(ColorTokens.Background.primary)
        .task { await viewModel.initialLoad() }
    }

    // MARK: - Section Toolbar

    @ViewBuilder
    private var sectionToolbar: some View {
        Picker("Product", selection: Binding(
            get: { viewModel.selectedProduct },
            set: { product in Task { await viewModel.switchProduct(to: product) } }
        )) {
            ForEach(ErrorLogViewModel.LogProduct.allCases) { product in
                Text(product.rawValue).tag(product)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 200)
    }

    @ViewBuilder
    private var archivePicker: some View {
        Picker(selection: $viewModel.selectedArchive) {
            if viewModel.sortedArchives.isEmpty {
                Text("Current").tag(viewModel.selectedArchive)
            } else {
                ForEach(viewModel.sortedArchives) { archive in
                    Text(archive.archiveNumber == 0
                        ? "Current \u{2014} \(archive.date)"
                        : "Archive #\(archive.archiveNumber) \u{2014} \(archive.date)")
                        .tag(archive.archiveNumber)
                }
            }
        } label: {
            EmptyView()
        }
        .pickerStyle(.menu)
        .fixedSize()
        .labelsHidden()
        .onChange(of: viewModel.selectedArchive) {
            Task { await viewModel.loadEntries() }
        }
    }

    // MARK: - Table

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
        .overlay {
            if !viewModel.isLoading && viewModel.filteredEntries.isEmpty {
                ContentUnavailableView {
                    Label(
                        viewModel.searchText.isEmpty ? "No Log Entries" : "No Results",
                        systemImage: "doc.text.magnifyingglass"
                    )
                } description: {
                    Text(viewModel.searchText.isEmpty
                        ? "The error log is empty."
                        : "No entries match \u{201c}\(viewModel.searchText)\u{201d}.")
                }
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
