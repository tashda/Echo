import SwiftUI
import SQLServerKit

struct EnableSystemVersioningSheet: View {
    let tableName: String
    let schemaName: String
    let session: ConnectionSession
    let environmentState: EnvironmentState
    let onDismiss: () -> Void

    @State private var startColumn = "ValidFrom"
    @State private var endColumn = "ValidTo"
    @State private var historyTableName: String
    @State private var historySchema: String
    @State private var isCreating = false
    @State private var errorMessage: String?

    init(
        tableName: String,
        schemaName: String,
        session: ConnectionSession,
        environmentState: EnvironmentState,
        onDismiss: @escaping () -> Void
    ) {
        self.tableName = tableName
        self.schemaName = schemaName
        self.session = session
        self.environmentState = environmentState
        self.onDismiss = onDismiss
        self._historyTableName = State(initialValue: "\(tableName)_History")
        self._historySchema = State(initialValue: schemaName)
    }

    var canCreate: Bool {
        Self.isCreateValid(
            startColumn: startColumn,
            endColumn: endColumn,
            historyTableName: historyTableName,
            isCreating: isCreating
        )
    }

    var body: some View {
        SheetLayout(
            title: "Enable System Versioning",
            icon: "clock.arrow.circlepath",
            subtitle: "Enable temporal table versioning for change tracking.",
            primaryAction: "Enable",
            canSubmit: canCreate,
            isSubmitting: isCreating,
            errorMessage: errorMessage,
            onSubmit: { await enableVersioning() },
            onCancel: { onDismiss() }
        ) {
            Form {
                Section("Table") {
                    LabeledContent("Schema") {
                        Text(schemaName)
                            .foregroundStyle(ColorTokens.Text.primary)
                            .fontWeight(.medium)
                    }
                    LabeledContent("Table") {
                        Text(tableName)
                            .foregroundStyle(ColorTokens.Text.primary)
                            .fontWeight(.medium)
                    }
                }

                Section("Period Columns") {
                    TextField("Start Column", text: $startColumn, prompt: Text("e.g. ValidFrom"))
                    TextField("End Column", text: $endColumn, prompt: Text("e.g. ValidTo"))
                }

                Section("History Table") {
                    TextField("Schema", text: $historySchema, prompt: Text("e.g. dbo"))
                    TextField("Table Name", text: $historyTableName, prompt: Text("e.g. Orders_History"))
                }

                Section {
                    Label {
                        Text("Enabling system versioning adds two datetime2 period columns and creates a history table to track all row changes automatically.")
                            .font(TypographyTokens.formDescription)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    } icon: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 480, minHeight: 340)
        .frame(idealWidth: 520, idealHeight: 400)
    }

    // MARK: - Validation (Internal for testability)

    static func isCreateValid(
        startColumn: String,
        endColumn: String,
        historyTableName: String,
        isCreating: Bool
    ) -> Bool {
        !startColumn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !endColumn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !historyTableName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isCreating
    }

    private func enableVersioning() async {
        isCreating = true
        errorMessage = nil
        let handle = AppDirector.shared.activityEngine.begin(
            "Enable system versioning on \(schemaName).\(tableName)",
            connectionSessionID: session.id
        )

        do {
            guard let mssql = session.session as? MSSQLSession else { return }
            let trimmedHistSchema = historySchema.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedHistTable = historyTableName.trimmingCharacters(in: .whitespacesAndNewlines)
            try await mssql.temporal.addPeriodColumnsAndEnableVersioning(
                database: session.sidebarFocusedDatabase ?? "",
                schema: schemaName,
                table: tableName,
                startColumn: startColumn.trimmingCharacters(in: .whitespacesAndNewlines),
                endColumn: endColumn.trimmingCharacters(in: .whitespacesAndNewlines),
                historySchema: trimmedHistSchema.isEmpty ? nil : trimmedHistSchema,
                historyTable: trimmedHistTable.isEmpty ? nil : trimmedHistTable
            )
            handle.succeed()
            environmentState.notificationEngine?.post(
                category: .maintenanceCompleted,
                message: "System versioning enabled on \(schemaName).\(tableName)."
            )
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
            handle.fail(error.localizedDescription)
            isCreating = false
        }
    }
}
