import SwiftUI
import MySQLKit

struct MySQLActivityIO: View {
    @Bindable var viewModel: ActivityMonitorViewModel
    @State private var report: MySQLPerformanceReport?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var filterText = ""

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .task { await load() }
    }

    private var toolbar: some View {
        HStack(spacing: SpacingTokens.sm) {
            Text("File I/O by Bytes")
                .font(TypographyTokens.headline)

            TextField("", text: $filterText, prompt: Text("Filter by file path"))
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)

            Spacer()

            if let report {
                Text("\(filteredRows.count) of \(report.rows.count) files")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            Button {
                Task { await load() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.sm)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && report == nil {
            ActivitySectionLoadingView(
                title: "File I/O",
                subtitle: "Loading from performance_schema\u{2026}"
            )
        } else if let errorMessage {
            ContentUnavailableView {
                Label("I/O Stats Unavailable", systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Retry") { Task { await load() } }
                    .buttonStyle(.bordered)
            }
        } else if let report {
            ioTable(report)
        }
    }

    private var filteredRows: [[String: String?]] {
        guard let report else { return [] }
        let normalized = filterText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return report.rows }
        return report.rows.filter { row in
            row.contains { _, value in
                (value ?? "").lowercased().contains(normalized)
            }
        }
    }

    private func ioTable(_ report: MySQLPerformanceReport) -> some View {
        let columns = report.rows
            .reduce(into: [String]()) { result, row in
                for key in row.keys where !result.contains(key) {
                    result.append(key)
                }
            }

        let rows = filteredRows.enumerated().map { offset, values in
            IORow(id: offset, values: values)
        }

        return Group {
            if rows.isEmpty {
                ContentUnavailableView {
                    Label("No I/O Activity", systemImage: "externaldrive")
                } description: {
                    Text("No file I/O statistics available.")
                }
            } else {
                ScrollView([.horizontal, .vertical]) {
                    Grid(alignment: .leading, horizontalSpacing: SpacingTokens.md, verticalSpacing: SpacingTokens.xs) {
                        GridRow {
                            ForEach(columns, id: \.self) { column in
                                Text(column.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(TypographyTokens.detail.weight(.semibold))
                                    .foregroundStyle(ColorTokens.Text.secondary)
                                    .frame(minWidth: 100, idealWidth: 160, maxWidth: 260, alignment: .leading)
                            }
                        }

                        Divider()
                            .gridCellColumns(columns.count)

                        ForEach(rows) { row in
                            GridRow {
                                ForEach(columns, id: \.self) { column in
                                    Text((row.values[column] ?? nil) ?? "")
                                        .font(TypographyTokens.Table.sql)
                                        .textSelection(.enabled)
                                        .lineLimit(1)
                                        .frame(minWidth: 100, idealWidth: 160, maxWidth: 260, alignment: .leading)
                                }
                            }
                        }
                    }
                    .padding(SpacingTokens.sm)
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            report = try await viewModel.loadMySQLFileIO()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct IORow: Identifiable {
    let id: Int
    let values: [String: String?]
}
