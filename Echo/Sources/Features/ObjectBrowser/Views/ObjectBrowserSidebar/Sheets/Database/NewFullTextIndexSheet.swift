import SwiftUI
import SQLServerKit

/// Sheet for creating a new full-text index on a table.
struct NewFullTextIndexSheet: View {
    let catalogs: [SQLServerFullTextCatalog]
    let session: ConnectionSession
    let onCreated: () -> Void
    let onCancel: () -> Void

    @State private var schema = "dbo"
    @State private var tableName = ""
    @State private var keyIndexName = ""
    @State private var selectedCatalog: String = ""
    @State private var columnsText = ""
    @State private var changeTracking: SQLServerFullTextClient.ChangeTrackingMode = .auto
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Target Table") {
                    TextField("Schema", text: $schema, prompt: Text("dbo"))
                    TextField("Table Name", text: $tableName, prompt: Text("e.g. Products"))
                    TextField("Unique Key Index", text: $keyIndexName, prompt: Text("e.g. PK_Products"))
                }

                Section("Index Configuration") {
                    Picker("Catalog", selection: $selectedCatalog) {
                        Text("Default").tag("")
                        ForEach(catalogs) { catalog in
                            Text(catalog.name).tag(catalog.name)
                        }
                    }

                    TextField("Columns", text: $columnsText, prompt: Text("e.g. Name, Description"))

                    Picker("Change Tracking", selection: $changeTracking) {
                        Text("Auto").tag(SQLServerFullTextClient.ChangeTrackingMode.auto)
                        Text("Manual").tag(SQLServerFullTextClient.ChangeTrackingMode.manual)
                        Text("Off").tag(SQLServerFullTextClient.ChangeTrackingMode.off)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(ColorTokens.Status.error)
                            .font(TypographyTokens.detail)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Create Index") {
                    Task { await createIndex() }
                }
                .buttonStyle(.bordered)
                .disabled(!canCreate)
                .keyboardShortcut(.defaultAction)
            }
            .padding(SpacingTokens.md)
        }
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            if let first = catalogs.first(where: \.isDefault) {
                selectedCatalog = first.name
            }
        }
    }

    private var canCreate: Bool {
        !tableName.trimmingCharacters(in: .whitespaces).isEmpty
            && !keyIndexName.trimmingCharacters(in: .whitespaces).isEmpty
            && !parsedColumns.isEmpty
            && !isCreating
    }

    private var parsedColumns: [String] {
        columnsText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func createIndex() async {
        guard let mssql = session.session as? MSSQLSession else {
            errorMessage = "Not a SQL Server connection."
            return
        }

        isCreating = true
        errorMessage = nil

        do {
            try await mssql.fullText.createIndex(
                schema: schema.trimmingCharacters(in: .whitespaces),
                table: tableName.trimmingCharacters(in: .whitespaces),
                keyIndex: keyIndexName.trimmingCharacters(in: .whitespaces),
                catalogName: selectedCatalog.isEmpty ? nil : selectedCatalog,
                columns: parsedColumns,
                changeTracking: changeTracking
            )
            onCreated()
        } catch {
            errorMessage = error.localizedDescription
        }

        isCreating = false
    }
}
