import SwiftUI
import MySQLKit

struct MySQLPerformanceReportsSection: View {
    @Bindable var viewModel: ActivityMonitorViewModel
    @State private var filterText: String = ""

    var body: some View {
        SectionContainer(
            title: "Performance Reports",
            icon: "speedometer",
            info: "Performance Schema and sys schema reports surfaced through mysql-wire."
        ) {
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                header
                reportContent
                    .padding(.horizontal, SpacingTokens.md)
                    .padding(.bottom, SpacingTokens.md)
            }
        }
        .task(id: viewModel.selectedMySQLPerformanceReport) {
            if viewModel.mysqlPerformanceReport?.name != viewModel.selectedMySQLPerformanceReport.rawValue {
                viewModel.loadMySQLPerformanceReport()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack(spacing: SpacingTokens.sm) {
                Picker("Report", selection: $viewModel.selectedMySQLPerformanceReport) {
                    ForEach(MySQLPerformanceReportKind.allCases) { report in
                        Text(report.title).tag(report)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 260, alignment: .leading)
                .onChange(of: viewModel.selectedMySQLPerformanceReport) {
                    filterText = ""
                    viewModel.loadMySQLPerformanceReport()
                }

                TextField("", text: $filterText, prompt: Text("Filter report rows"))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)

                Spacer()

                Button("Retry") {
                    viewModel.loadMySQLPerformanceReport()
                }
                .buttonStyle(.borderless)
            }

            if let report = viewModel.mysqlPerformanceReport {
                HStack(spacing: SpacingTokens.md) {
                    Text("\(filteredRowCount(for: report)) of \(report.rows.count) rows")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)

                    Button("Copy CSV") {
                        PlatformClipboard.copy(exportedText(for: report, format: .csv))
                    }
                    .buttonStyle(.borderless)
                    .disabled(report.rows.isEmpty)

                    Button("Copy Markdown") {
                        PlatformClipboard.copy(exportedText(for: report, format: .markdown))
                    }
                    .buttonStyle(.borderless)
                    .disabled(report.rows.isEmpty)
                }
            }
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.top, SpacingTokens.md)
    }

    @ViewBuilder
    private var reportContent: some View {
        if viewModel.isLoadingMySQLPerformanceReport && viewModel.mysqlPerformanceReport == nil {
            ActivitySectionLoadingView(
                title: viewModel.selectedMySQLPerformanceReport.title,
                subtitle: "Loading Performance Schema report…"
            )
            .frame(minHeight: 220)
        } else if let error = viewModel.mysqlPerformanceReportError {
            ContentUnavailableView {
                Label("Report Unavailable", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            } actions: {
                Button("Retry") {
                    viewModel.loadMySQLPerformanceReport()
                }
                .buttonStyle(.bordered)
            }
            .frame(minHeight: 220)
        } else if let report = viewModel.mysqlPerformanceReport {
            MySQLPerformanceReportTable(report: report, filterText: filterText)
        } else {
            ActivitySectionLoadingView(
                title: viewModel.selectedMySQLPerformanceReport.title,
                subtitle: "Preparing report view…"
            )
            .frame(minHeight: 220)
        }
    }

    private func filteredRowCount(for report: MySQLPerformanceReport) -> Int {
        MySQLPerformanceReportTable.filteredRows(from: report, filterText: filterText).count
    }

    private func exportedText(for report: MySQLPerformanceReport, format: ResultExportFormat) -> String {
        let rows = MySQLPerformanceReportTable.filteredRows(from: report, filterText: filterText)
            .map { row in
                MySQLPerformanceReportTable.columns(from: report).map { row[$0] ?? nil }
            }
        return ResultTableExportFormatter.format(
            format,
            headers: MySQLPerformanceReportTable.columns(from: report),
            rows: rows,
            tableName: report.name,
            databaseType: .mysql
        )
    }
}

private struct MySQLPerformanceReportTable: View {
    struct Row: Identifiable {
        let id: Int
        let values: [String: String?]
    }

    let report: MySQLPerformanceReport
    let filterText: String

    static func columns(from report: MySQLPerformanceReport) -> [String] {
        report.rows
            .reduce(into: Set<String>()) { partialResult, row in
                partialResult.formUnion(row.keys)
            }
            .sorted()
    }

    static func filteredRows(from report: MySQLPerformanceReport, filterText: String) -> [[String: String?]] {
        let normalized = filterText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return report.rows }
        return report.rows.filter { row in
            row.contains { key, value in
                key.lowercased().contains(normalized) ||
                (value ?? "").lowercased().contains(normalized)
            }
        }
    }

    private var columns: [String] {
        Self.columns(from: report)
    }

    private var rows: [Row] {
        Self.filteredRows(from: report, filterText: filterText).enumerated().map { offset, row in
            Row(id: offset, values: row)
        }
    }

    var body: some View {
        if report.rows.isEmpty {
            ContentUnavailableView {
                Label("No Report Rows", systemImage: "tablecells")
            } description: {
                Text("The selected sys report returned no rows.")
            }
            .frame(minHeight: 220)
        } else if rows.isEmpty {
            ContentUnavailableView {
                Label("No Matching Rows", systemImage: "line.3.horizontal.decrease.circle")
            } description: {
                Text("The current filter does not match any rows in this MySQL performance report.")
            }
            .frame(minHeight: 220)
        } else {
            ScrollView([.horizontal, .vertical]) {
                Grid(alignment: .leading, horizontalSpacing: SpacingTokens.md, verticalSpacing: SpacingTokens.xs) {
                    GridRow {
                        ForEach(columns, id: \.self) { column in
                            Text(columnDisplayName(column))
                                .font(TypographyTokens.detail.weight(.semibold))
                                .foregroundStyle(ColorTokens.Text.secondary)
                                .frame(minWidth: 140, idealWidth: 220, maxWidth: 280, alignment: .leading)
                        }
                    }

                    Divider()
                        .gridCellColumns(columns.count)

                    ForEach(rows) { row in
                        GridRow {
                            ForEach(columns, id: \.self) { column in
                                Text(cellText(row, column: column))
                                    .font(TypographyTokens.Table.sql)
                                    .textSelection(.enabled)
                                    .lineLimit(1)
                                    .frame(minWidth: 140, idealWidth: 220, maxWidth: 280, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(SpacingTokens.sm)
            }
            .frame(minHeight: 260)
        }
    }

    private func columnDisplayName(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func cellText(_ row: Row, column: String) -> String {
        if let value = row.values[column] ?? nil {
            return value
        }
        return ""
    }
}
