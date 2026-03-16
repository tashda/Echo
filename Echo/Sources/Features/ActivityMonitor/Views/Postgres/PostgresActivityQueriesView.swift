import SwiftUI
import PostgresWire

struct PostgresActivityQueriesView: View {
    let snap: PostgresActivitySnapshot
    @Binding var sortOrder: [KeyPathComparator<PostgresExpensiveQuery>]
    @Binding var selection: Set<PostgresExpensiveQuery.ID>
    let onPopout: (String) -> Void
    let onOpenExtensionManager: () -> Void
    var onDoubleClick: (() -> Void)?

    @State private var showEnablePopover = false

    var body: some View {
        if snap.pgStatStatementsAvailable {
            PostgresExpensiveQueriesTable(
                queries: snap.expensiveQueries,
                sortOrder: $sortOrder,
                selection: $selection,
                onPopout: onPopout,
                onDoubleClick: onDoubleClick
            )
        } else {
            pgStatStatementsUnavailable
        }
    }

    private var pgStatStatementsUnavailable: some View {
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

struct PostgresExpensiveQueriesTable: View {
    let queries: [PostgresExpensiveQuery]
    @Binding var sortOrder: [KeyPathComparator<PostgresExpensiveQuery>]
    @Binding var selection: Set<PostgresExpensiveQuery.ID>
    let onPopout: (String) -> Void
    var onDoubleClick: (() -> Void)?

    private var sortedQueries: [PostgresExpensiveQuery] {
        queries.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedQueries, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Query") { SQLQueryCell(sql: $0.query, onPopout: onPopout) }
            TableColumn("Calls", value: \.calls) {
                Text("\($0.calls)").font(TypographyTokens.detail.monospacedDigit())
            }.width(60)
            TableColumn("Total Time", value: \.total_exec_time) {
                Text(String(format: "%.1fms", $0.total_exec_time))
                    .font(TypographyTokens.detail.monospacedDigit())
                    .foregroundStyle(ColorTokens.accent)
            }.width(90)
            TableColumn("Mean Time", value: \.mean_exec_time) {
                Text(String(format: "%.1fms", $0.mean_exec_time))
                    .font(TypographyTokens.detail.monospacedDigit())
                    .foregroundStyle(ColorTokens.Text.secondary)
            }.width(80)
            TableColumn("Rows", value: \.rows) {
                Text("\($0.rows)").font(TypographyTokens.detail.monospacedDigit())
            }.width(70)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: PostgresExpensiveQuery.ID.self) { ids in
            if let id = ids.first, let query = queries.first(where: { $0.id == id }) {
                Button("Details") {
                    onPopout(query.query)
                }
            }
        } primaryAction: { _ in
            onDoubleClick?()
        }
    }
}
