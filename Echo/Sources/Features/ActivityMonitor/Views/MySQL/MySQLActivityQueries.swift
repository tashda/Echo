import SwiftUI
import MySQLKit

struct MySQLActivityQueries: View {
    enum QueryReportType: String, CaseIterable {
        case statementAnalysis = "Statement Analysis"
        case topRuntime = "Top Runtime (95th %ile)"
        case fullTableScans = "Full Table Scans"
    }

    @Bindable var viewModel: ActivityMonitorViewModel
    let onInspect: (DatabaseObjectInspectorContent?) -> Void
    let onPopout: (String) -> Void

    @State private var selectedReport: QueryReportType = .statementAnalysis
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
        .onChange(of: selectedReport) {
            Task { await load() }
        }
    }

    private var toolbar: some View {
        HStack(spacing: SpacingTokens.sm) {
            Picker("Report", selection: $selectedReport) {
                ForEach(QueryReportType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 420)

            TextField("", text: $filterText, prompt: Text("Filter"))
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)

            Spacer()

            if let report {
                Text("\(filteredRows.count) of \(report.rows.count) rows")
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
                title: selectedReport.rawValue,
                subtitle: "Loading from performance_schema\u{2026}"
            )
        } else if let errorMessage {
            ContentUnavailableView {
                Label("Report Unavailable", systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Retry") { Task { await load() } }
                    .buttonStyle(.bordered)
            }
        } else if let report {
            queryTable(report)
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

    private func queryTable(_ report: MySQLPerformanceReport) -> some View {
        let columns = report.rows
            .reduce(into: [String]()) { result, row in
                for key in row.keys where !result.contains(key) {
                    result.append(key)
                }
            }

        let rows = filteredRows.enumerated().map { offset, values in
            ReportRow(id: offset, values: values)
        }

        return ScrollView([.horizontal, .vertical]) {
            Grid(alignment: .leading, horizontalSpacing: SpacingTokens.md, verticalSpacing: SpacingTokens.xs) {
                GridRow {
                    ForEach(columns, id: \.self) { column in
                        Text(column.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(TypographyTokens.detail.weight(.semibold))
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .frame(minWidth: 120, idealWidth: 200, maxWidth: 280, alignment: .leading)
                    }
                }

                Divider()
                    .gridCellColumns(columns.count)

                ForEach(rows) { row in
                    GridRow {
                        ForEach(columns, id: \.self) { column in
                            let value = row.values[column] ?? nil
                            if let value, looksLikeSQL(value) {
                                SQLQueryCell(sql: value) { sql in
                                    onPopout(sql)
                                }
                                .frame(minWidth: 120, idealWidth: 200, maxWidth: 280, alignment: .leading)
                            } else {
                                Text(value ?? "")
                                    .font(TypographyTokens.Table.sql)
                                    .textSelection(.enabled)
                                    .lineLimit(1)
                                    .frame(minWidth: 120, idealWidth: 200, maxWidth: 280, alignment: .leading)
                            }
                        }
                    }
                }
            }
            .padding(SpacingTokens.sm)
        }
    }

    private func looksLikeSQL(_ value: String) -> Bool {
        let upper = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return upper.hasPrefix("SELECT") || upper.hasPrefix("INSERT") || upper.hasPrefix("UPDATE") ||
               upper.hasPrefix("DELETE") || upper.hasPrefix("CALL") || upper.hasPrefix("CREATE")
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let result: MySQLPerformanceReport
            switch selectedReport {
            case .statementAnalysis:
                result = try await viewModel.loadMySQLStatementAnalysis()
            case .topRuntime:
                result = try await viewModel.loadMySQLTopRuntimeStatements()
            case .fullTableScans:
                result = try await viewModel.loadMySQLFullTableScans()
            }
            report = result
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct ReportRow: Identifiable {
    let id: Int
    let values: [String: String?]
}
