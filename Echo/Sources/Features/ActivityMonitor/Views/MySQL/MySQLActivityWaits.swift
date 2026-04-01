import SwiftUI
import MySQLKit

struct MySQLActivityWaits: View {
    enum WaitsTab: String, CaseIterable {
        case global = "Global Waits"
        case byUser = "By User"
        case locks = "Locks"
    }

    @Bindable var viewModel: ActivityMonitorViewModel
    @State private var selectedTab: WaitsTab = .global
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
        .onChange(of: selectedTab) {
            report = nil
            Task { await load() }
        }
    }

    private var toolbar: some View {
        HStack(spacing: SpacingTokens.sm) {
            Picker("Tab", selection: $selectedTab) {
                ForEach(WaitsTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)

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
                title: selectedTab.rawValue,
                subtitle: "Loading from performance_schema\u{2026}"
            )
        } else if let errorMessage {
            ContentUnavailableView {
                Label("Data Unavailable", systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
                if selectedTab == .locks {
                    Text("Lock monitoring requires the sys schema and performance_schema.")
                        .font(TypographyTokens.detail)
                }
            } actions: {
                Button("Retry") { Task { await load() } }
                    .buttonStyle(.bordered)
            }
        } else if let report {
            reportTable(report)
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

    private func reportTable(_ report: MySQLPerformanceReport) -> some View {
        let columns = report.rows
            .reduce(into: [String]()) { result, row in
                for key in row.keys where !result.contains(key) {
                    result.append(key)
                }
            }

        let rows = filteredRows.enumerated().map { offset, values in
            WaitRow(id: offset, values: values)
        }

        return Group {
            if rows.isEmpty {
                ContentUnavailableView {
                    Label(emptyTitle, systemImage: emptyIcon)
                } description: {
                    Text(emptyDescription)
                }
            } else {
                ScrollView([.horizontal, .vertical]) {
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
                                    Text((row.values[column] ?? nil) ?? "")
                                        .font(TypographyTokens.Table.sql)
                                        .textSelection(.enabled)
                                        .lineLimit(1)
                                        .frame(minWidth: 120, idealWidth: 200, maxWidth: 280, alignment: .leading)
                                }
                            }
                        }
                    }
                    .padding(SpacingTokens.sm)
                }
            }
        }
    }

    private var emptyTitle: String {
        selectedTab == .locks ? "No Active Locks" : "No Wait Events"
    }

    private var emptyIcon: String {
        selectedTab == .locks ? "lock.open" : "clock"
    }

    private var emptyDescription: String {
        selectedTab == .locks
            ? "No InnoDB lock waits detected."
            : "No wait events recorded in this interval."
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            switch selectedTab {
            case .global:
                report = try await viewModel.loadMySQLWaitsGlobal()
            case .byUser:
                report = try await viewModel.loadMySQLWaitsByUser()
            case .locks:
                report = try await viewModel.loadMySQLReport(
                    "SELECT * FROM sys.innodb_lock_waits LIMIT 50",
                    name: "innodb_lock_waits"
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct WaitRow: Identifiable {
    let id: Int
    let values: [String: String?]
}
