import SwiftUI
import MySQLKit

struct MySQLPerformanceReportsSection: View {
    @Bindable var viewModel: ActivityMonitorViewModel

    var body: some View {
        SectionContainer(
            title: "Performance Reports",
            icon: "speedometer",
            info: "Performance Schema and sys schema reports surfaced through mysql-wire."
        ) {
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                Picker("Report", selection: $viewModel.selectedMySQLPerformanceReport) {
                    ForEach(MySQLPerformanceReportKind.allCases) { report in
                        Text(report.title).tag(report)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 260, alignment: .leading)
                .padding(.horizontal, SpacingTokens.md)
                .padding(.top, SpacingTokens.md)
                .onChange(of: viewModel.selectedMySQLPerformanceReport) {
                    viewModel.loadMySQLPerformanceReport()
                }

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
            MySQLPerformanceReportTable(report: report)
        } else {
            ActivitySectionLoadingView(
                title: viewModel.selectedMySQLPerformanceReport.title,
                subtitle: "Preparing report view…"
            )
            .frame(minHeight: 220)
        }
    }
}

private struct MySQLPerformanceReportTable: View {
    struct Row: Identifiable {
        let id: Int
        let values: [String: String?]
    }

    let report: MySQLPerformanceReport

    private var columns: [String] {
        report.rows
            .reduce(into: Set<String>()) { partialResult, row in
                partialResult.formUnion(row.keys)
            }
            .sorted()
    }

    private var rows: [Row] {
        report.rows.enumerated().map { offset, row in
            Row(id: offset, values: row)
        }
    }

    var body: some View {
        if rows.isEmpty {
            ContentUnavailableView {
                Label("No Report Rows", systemImage: "tablecells")
            } description: {
                Text("The selected sys report returned no rows.")
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
