import SwiftUI
import SQLServerKit
import PostgresWire

struct StatusBadge: View {
    let text: String
    let isSystem: Bool

    init(text: String, isSystem: Bool = false) {
        self.text = text.isEmpty ? (isSystem ? "System" : "Unknown") : text
        self.isSystem = isSystem
    }

    var body: some View {
        Text(text)
            .font(TypographyTokens.compact.weight(.bold))
            .padding(.horizontal, SpacingTokens.xxs2)
            .padding(.vertical, SpacingTokens.xxxs)
            .background(backgroundColor.opacity(0.15))
            .foregroundStyle(backgroundColor)
            .cornerRadius(4)
    }

    private var backgroundColor: Color {
        if isSystem { return ColorTokens.Status.info }
        switch text.lowercased() {
        case "active", "running", "runnable": return ColorTokens.Status.success
        case "sleeping", "idle": return ColorTokens.Text.secondary
        case "suspended", "blocked": return ColorTokens.Status.error
        default: return ColorTokens.Text.secondary
        }
    }
}

struct ProcessesTableView: View {
    var viewModel: ActivityMonitorViewModel
    @Binding var sortOrder: [KeyPathComparator<SQLServerProcessInfo>]
    @Binding var pgSortOrder: [KeyPathComparator<PostgresProcessInfo>]
    let onPopout: (String) -> Void

    var body: some View {
        if let snapshot = viewModel.latestSnapshot {
            switch snapshot {
            case .mssql(let snap):
                MSSQLProcessesTable(processes: snap.processes, sortOrder: $sortOrder, onPopout: onPopout, onKill: { id in
                    Task { try? await viewModel.killSession(id: id) }
                })
            case .postgres(let snap):
                PostgresProcessesTable(processes: snap.processes, sortOrder: $pgSortOrder, onPopout: onPopout, onKill: { id in
                    Task { try? await viewModel.killSession(id: id) }
                })
            }
        } else {
            EmptyTablePlaceholder()
        }
    }
}

struct ResourceWaitsTableView: View {
    var viewModel: ActivityMonitorViewModel
    @Binding var sortOrder: [KeyPathComparator<SQLServerWaitStatDelta>]
    @Binding var pgSortOrder: [KeyPathComparator<PostgresWaitStatDelta>]

    var body: some View {
        if let snapshot = viewModel.latestSnapshot {
            switch snapshot {
            case .mssql(let snap):
                MSSQLWaitsTable(waits: snap.waitsDelta ?? [], sortOrder: $sortOrder)
            case .postgres(let snap):
                PostgresWaitsTable(waits: snap.waitsDelta ?? [], sortOrder: $pgSortOrder)
            }
        } else {
            EmptyTablePlaceholder()
        }
    }
}

struct DataFileIOTableView: View {
    var viewModel: ActivityMonitorViewModel
    @Binding var sortOrder: [KeyPathComparator<SQLServerFileIOStatDelta>]
    @Binding var pgSortOrder: [KeyPathComparator<PostgresDatabaseStatDelta>]

    var body: some View {
        if let snapshot = viewModel.latestSnapshot {
            switch snapshot {
            case .mssql(let snap):
                MSSQLFileIOTable(io: snap.fileIODelta ?? [], sortOrder: $sortOrder)
            case .postgres(let snap):
                PostgresDBStatsTable(stats: snap.databaseStatsDelta ?? [], sortOrder: $pgSortOrder)
            }
        } else {
            EmptyTablePlaceholder()
        }
    }
}

struct ExpensiveQueriesTableView: View {
    var viewModel: ActivityMonitorViewModel
    @Binding var sortOrder: [KeyPathComparator<SQLServerExpensiveQuery>]
    @Binding var pgSortOrder: [KeyPathComparator<PostgresExpensiveQuery>]
    let onOpenExtensionManager: () -> Void
    let onPopout: (String) -> Void

    @State private var showEnablePopover = false

    var body: some View {
        if let snapshot = viewModel.latestSnapshot {
            switch snapshot {
            case .mssql(let snap):
                MSSQLExpensiveQueriesTable(queries: snap.expensiveQueries, sortOrder: $sortOrder, onPopout: onPopout)
            case .postgres(let snap):
                if snap.pgStatStatementsAvailable {
                    PostgresExpensiveQueriesTable(queries: snap.expensiveQueries, sortOrder: $pgSortOrder, onPopout: onPopout)
                } else {
                    VStack(spacing: SpacingTokens.md) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(TypographyTokens.hero)
                            .foregroundStyle(ColorTokens.Status.warning)
                        Text("pg_stat_statements Not Found")
                            .font(TypographyTokens.headline)
                        Text("This extension is required to track expensive queries in PostgreSQL.")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .multilineTextAlignment(.center)

                        Button("How to enable?") {
                            showEnablePopover = true
                        }
                        .buttonStyle(.link)
                        .popover(isPresented: $showEnablePopover) {
                            PGStatStatementsGuide(onOpenManager: {
                                showEnablePopover = false
                                onOpenExtensionManager()
                            })
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(SpacingTokens.lg)
                }
            }
        } else {
            EmptyTablePlaceholder()
        }
    }
}

struct PGStatStatementsGuide: View {
    let onOpenManager: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Image(systemName: "puzzlepiece.extension.fill")
                    .foregroundStyle(ColorTokens.Status.info)
                Text("Enable Expensive Query Tracking")
                    .font(TypographyTokens.headline)
            }

            Text("PostgreSQL requires the `pg_stat_statements` extension to track detailed query performance metrics.")
                .font(TypographyTokens.detail)

            VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
                Label("Add to `shared_preload_libraries` in `postgresql.conf`", systemImage: "1.circle")
                Label("Restart the PostgreSQL server", systemImage: "2.circle")
                Label("Run `CREATE EXTENSION pg_stat_statements;`", systemImage: "3.circle")
            }
            .font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.Text.secondary)

            Button("Open Extension Manager") {
                onOpenManager()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .padding(.top, SpacingTokens.xxs)
        }
        .padding(SpacingTokens.lg)
        .frame(width: 380)
    }
}

struct EmptyTablePlaceholder: View {
    var body: some View {
        VStack {
            Text("No activity data available")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
