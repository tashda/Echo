import SwiftUI
import SQLServerKit

struct NewExternalTableSheet: View {
    let databaseName: String
    let session: ConnectionSession
    let environmentState: EnvironmentState
    let onDismiss: () -> Void

    @State private var schema = "dbo"
    @State private var name = ""
    @State private var location = ""
    @State private var dataSource = ""
    @State private var fileFormat = ""
    @State private var columns: [(id: UUID, name: String, dataType: String)] = [(UUID(), "", "")]
    @State private var isCreating = false
    @State private var errorMessage: String?

    var canCreate: Bool {
        Self.isCreateValid(
            name: name,
            dataSource: dataSource,
            location: location,
            columns: columns,
            isCreating: isCreating
        )
    }

    var body: some View {
        SheetLayout(
            title: "New External Table",
            icon: "externaldrive",
            subtitle: "Create a PolyBase external table referencing an external data source.",
            primaryAction: "Create",
            canSubmit: canCreate,
            isSubmitting: isCreating,
            errorMessage: errorMessage,
            onSubmit: { await create() },
            onCancel: { onDismiss() }
        ) {
            Form {
                Section("Table") {
                    TextField("Schema", text: $schema, prompt: Text("e.g. dbo"))
                    TextField("Name", text: $name, prompt: Text("e.g. ExternalOrders"))
                }

                Section("External Source") {
                    TextField("Data Source", text: $dataSource, prompt: Text("e.g. MyHadoopCluster"))
                    TextField("Location", text: $location, prompt: Text("e.g. /data/orders/"))
                    TextField("File Format", text: $fileFormat, prompt: Text("e.g. MyParquetFormat"))
                }

                Section("Columns") {
                    ForEach(Array(columns.enumerated()), id: \.element.id) { index, _ in
                        HStack(spacing: SpacingTokens.sm) {
                            TextField("", text: columnNameBinding(at: index), prompt: Text("Column name"))
                            MSSQLDataTypePicker(selection: columnTypeBinding(at: index), prompt: "Data type")
                            Button {
                                removeColumn(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(ColorTokens.Status.error)
                            }
                            .buttonStyle(.borderless)
                            .disabled(columns.count <= 1)
                        }
                    }
                    Button {
                        columns.append((UUID(), "", ""))
                    } label: {
                        Label("Add Column", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 560, minHeight: 420)
        .frame(idealWidth: 600, idealHeight: 500)
    }

    // MARK: - Validation (Internal for testability)

    static func isCreateValid(
        name: String,
        dataSource: String,
        location: String,
        columns: [(id: UUID, name: String, dataType: String)],
        isCreating: Bool
    ) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDS = dataSource.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLoc = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasValidColumn = columns.contains { col in
            !col.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !col.dataType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return !trimmedName.isEmpty
            && !trimmedDS.isEmpty
            && !trimmedLoc.isEmpty
            && hasValidColumn
            && !isCreating
    }

    // MARK: - Column Bindings

    private func columnNameBinding(at index: Int) -> Binding<String> {
        Binding(
            get: { columns[index].name },
            set: { columns[index].name = $0 }
        )
    }

    private func columnTypeBinding(at index: Int) -> Binding<String> {
        Binding(
            get: { columns[index].dataType },
            set: { columns[index].dataType = $0 }
        )
    }

    private func removeColumn(at index: Int) {
        guard columns.count > 1 else { return }
        columns.remove(at: index)
    }

    private func create() async {
        isCreating = true
        errorMessage = nil
        let handle = AppDirector.shared.activityEngine.begin(
            "Create external table \(name)",
            connectionSessionID: session.id
        )

        do {
            guard let mssql = session.session as? MSSQLSession else { return }
            let trimmedFF = fileFormat.trimmingCharacters(in: .whitespacesAndNewlines)
            let cols = columns
                .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !$0.dataType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map { (name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines),
                         dataType: $0.dataType.trimmingCharacters(in: .whitespacesAndNewlines)) }
            try await mssql.polyBase.createExternalTable(
                database: databaseName,
                schema: schema.trimmingCharacters(in: .whitespacesAndNewlines),
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                columns: cols,
                location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                dataSource: dataSource.trimmingCharacters(in: .whitespacesAndNewlines),
                fileFormat: trimmedFF.isEmpty ? nil : trimmedFF
            )
            handle.succeed()
            environmentState.notificationEngine?.post(
                category: .maintenanceCompleted,
                message: "External table \(schema).\(name) created."
            )
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
            handle.fail(error.localizedDescription)
            isCreating = false
        }
    }
}
