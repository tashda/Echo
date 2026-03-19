import SwiftUI
import SQLServerKit

/// Panel with common database maintenance actions for SQL Server.
struct MaintenanceSheet: View {
    let databaseName: String
    let session: ConnectionSession
    let onDismiss: () -> Void

    @State var isRunning = false
    @State var results: [MaintenanceResultEntry] = []
    @State var schemas: [SchemaTablePair] = []
    @State var selectedSchema: String = "dbo"
    @State var selectedTable: String = ""
    @State var isLoadingTables = true

    struct SchemaTablePair: Hashable, Identifiable {
        var id: String { "\(schema).\(table)" }
        let schema: String
        let table: String
    }

    struct MaintenanceResultEntry: Identifiable {
        let id = UUID()
        let operation: String
        let succeeded: Bool
        let message: String
        let timestamp: Date
    }

    enum DatabaseOp { case checkDB, shrink }
    enum TableOp { case rebuildIndexes, reorganizeIndexes, updateStats }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            HStack(spacing: 0) {
                actionsPane
                    .frame(width: 240)
                Divider()
                resultsPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()
            footerBar
        }
        .frame(minWidth: 600, minHeight: 400)
        .frame(idealWidth: 640, idealHeight: 440)
        .task { await loadTables() }
    }

    private var headerBar: some View {
        HStack {
            Image(systemName: "wrench.and.screwdriver")
                .foregroundStyle(ColorTokens.accent)
            Text("Maintenance")
                .font(TypographyTokens.prominent.weight(.semibold))
            Spacer()
            Text(databaseName)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .padding(SpacingTokens.md)
    }

    private var footerBar: some View {
        HStack {
            if isRunning {
                ProgressView()
                    .controlSize(.small)
                Text("Running\u{2026}")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            Spacer()
            Button("Done") { onDismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(SpacingTokens.md)
    }

    func appendResult(operation: String, succeeded: Bool, message: String) {
        results.insert(
            MaintenanceResultEntry(
                operation: operation,
                succeeded: succeeded,
                message: message,
                timestamp: Date()
            ),
            at: 0
        )
    }

    func loadTables() async {
        do {
            let objects = try await session.session.listTablesAndViews(schema: nil)
            schemas = objects
                .filter { $0.type == .table }
                .map { SchemaTablePair(schema: $0.schema, table: $0.name) }
                .sorted { $0.id < $1.id }
            if let first = schemas.first {
                selectedSchema = first.schema
                selectedTable = first.table
            }
        } catch {
            // Tables couldn't be loaded; table operations will be disabled
        }
        isLoadingTables = false
    }
}
