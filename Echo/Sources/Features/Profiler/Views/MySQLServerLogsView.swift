import AppKit
import SwiftUI

struct MySQLServerLogsView: View {
    @Bindable var viewModel: ServerPropertiesViewModel
    @Environment(AppState.self) private var appState
    @Environment(EnvironmentState.self) private var environmentState

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.logDestinations.isEmpty {
                Table(viewModel.logDestinations) {
                    TableColumn("Destination") { item in
                        Text(item.name).font(TypographyTokens.Table.name)
                    }
                    .width(min: 160, ideal: 200)

                    TableColumn("Value") { item in
                        Text(item.value)
                            .font(TypographyTokens.Table.secondaryName)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .textSelection(.enabled)
                    }
                    .width(min: 260, ideal: 520)

                    TableColumn("") { item in
                        if let path = filePath(for: item) {
                            HStack(spacing: SpacingTokens.xs) {
                                Button("Open") {
                                    NSWorkspace.shared.openFile(path)
                                }
                                .buttonStyle(.borderless)

                                Button("Reveal") {
                                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    .width(min: 90, ideal: 120)
                }
                .tableStyle(.inset(alternatesRowBackgrounds: true))
                .tableColumnAutoResize()
                .frame(minHeight: 180)
            }

            Divider()

            TabSectionToolbar {
                Text("Error Log")
                    .font(TypographyTokens.prominent.weight(.semibold))
            }

            logTable(viewModel.errorLogRows, emptyTitle: "No Error Log Rows", emptyMessage: "No readable error log entries were found from the configured MySQL error log path.")
                .frame(minHeight: 180)

            Divider()

            TabSectionToolbar {
                Text("General Log")
                    .font(TypographyTokens.prominent.weight(.semibold))
            }

            logTable(viewModel.generalLogRows, emptyTitle: "No General Log Rows", emptyMessage: "Enable table-based general logging to inspect recent rows here.")
                .frame(minHeight: 180)

            Divider()

            TabSectionToolbar {
                Text("Slow Log")
                    .font(TypographyTokens.prominent.weight(.semibold))
            }

            logTable(viewModel.slowLogRows, emptyTitle: "No Slow Log Rows", emptyMessage: "Enable table-based slow logging to inspect recent rows here.")
                .frame(minHeight: 180)
        }
    }

    private func logTable(_ rows: [ServerPropertiesViewModel.LogRow], emptyTitle: String, emptyMessage: String) -> some View {
        Table(rows) {
            TableColumn("Time") { row in
                Text(row.timestamp)
                    .font(TypographyTokens.Table.date)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 120, ideal: 160)

            TableColumn("Summary") { row in
                Text(row.summary)
                    .font(TypographyTokens.Table.name)
                    .lineLimit(1)
            }
            .width(min: 300, ideal: 700)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .contextMenu(forSelectionType: ServerPropertiesViewModel.LogRow.ID.self) { ids in
            if let id = ids.first, let row = rows.first(where: { $0.id == id }) {
                Button {
                    pushInspector(row)
                } label: {
                    Label("View Details", systemImage: "info.circle")
                }
            }
        } primaryAction: { ids in
            if let id = ids.first, let row = rows.first(where: { $0.id == id }) {
                pushInspector(row)
            }
        }
        .overlay {
            if rows.isEmpty {
                ContentUnavailableView {
                    Label(emptyTitle, systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text(emptyMessage)
                }
            }
        }
    }

    private func pushInspector(_ row: ServerPropertiesViewModel.LogRow) {
        let content = DatabaseObjectInspectorContent(
            title: row.summary,
            subtitle: row.timestamp,
            fields: [.init(label: "Details", value: row.details)]
        )
        environmentState.toggleDataInspector(
            content: .databaseObject(content),
            title: row.summary,
            appState: appState
        )
    }

    private func filePath(for item: ServerPropertiesViewModel.PropertyItem) -> String? {
        let lowered = item.name.lowercased()
        guard lowered == "log_error" || lowered == "general_log_file" || lowered == "slow_query_log_file" else {
            return nil
        }

        let path = NSString(string: item.value).expandingTildeInPath
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else {
            return nil
        }
        return path
    }
}
