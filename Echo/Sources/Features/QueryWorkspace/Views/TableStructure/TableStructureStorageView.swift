import SwiftUI
import PostgresKit

struct TableStructureStorageView: View {
    @Bindable var viewModel: TableStructureEditorViewModel

    @State private var fillfactor = ""
    @State private var toastTupleTarget = ""
    @State private var autovacuumEnabled = true
    @State private var parallelWorkers = ""
    @State private var tablespace = ""
    @State private var isApplying = false
    @State private var loaded = false

    var body: some View {
        Form {
            Section("Storage Parameters") {
                PropertyRow(title: "Fill Factor") {
                    TextField("", text: $fillfactor, prompt: Text("e.g. 90 (default 100)"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
                PropertyRow(title: "TOAST Tuple Target") {
                    TextField("", text: $toastTupleTarget, prompt: Text("e.g. 128"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
                PropertyRow(title: "Parallel Workers") {
                    TextField("", text: $parallelWorkers, prompt: Text("e.g. 2"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Autovacuum") {
                PropertyRow(title: "Enabled") {
                    Toggle("", isOn: $autovacuumEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }

            Section("Tablespace") {
                PropertyRow(title: "Tablespace") {
                    TextField("", text: $tablespace, prompt: Text("e.g. pg_default"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section {
                HStack {
                    Spacer()
                    if !isApplying {
                        Button("Apply") { Task { await applyChanges() } }
                            .buttonStyle(.bordered)
                            .keyboardShortcut(.defaultAction)
                    } else {
                        Button("Apply") {}
                            .buttonStyle(.bordered)
                            .disabled(true)
                            .keyboardShortcut(.defaultAction)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .task { loadCurrentValues() }
    }

    private func loadCurrentValues() {
        guard !loaded, let props = viewModel.tableProperties else { return }
        loaded = true
        fillfactor = props.fillfactor.map(String.init) ?? ""
        toastTupleTarget = props.toastTupleTarget.map(String.init) ?? ""
        autovacuumEnabled = props.autovacuumEnabled ?? true
        parallelWorkers = props.parallelWorkers.map(String.init) ?? ""
        tablespace = props.tablespace ?? ""
    }

    private func applyChanges() async {
        guard let pg = viewModel.session as? PostgresSession else { return }
        isApplying = true
        defer { isApplying = false }

        let handle = viewModel.activityEngine?.begin("Updating storage parameters", connectionSessionID: viewModel.connectionSessionID)
        let schema = viewModel.schemaName
        let table = viewModel.tableName
        do {
            if let ff = Int(fillfactor), ff > 0 {
                try await pg.client.admin.alterTableSetParameter(table: table, parameter: "fillfactor", value: String(ff), schema: schema)
            }
            if let tt = Int(toastTupleTarget), tt > 0 {
                try await pg.client.admin.alterTableSetParameter(table: table, parameter: "toast_tuple_target", value: String(tt), schema: schema)
            }
            if let pw = Int(parallelWorkers), pw >= 0 {
                try await pg.client.admin.alterTableSetParameter(table: table, parameter: "parallel_workers", value: String(pw), schema: schema)
            }
            try await pg.client.admin.alterTableSetParameter(table: table, parameter: "autovacuum_enabled", value: autovacuumEnabled ? "true" : "false", schema: schema)
            if !tablespace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try await pg.client.admin.alterTableSetTablespace(table: table, tablespace: tablespace.trimmingCharacters(in: .whitespacesAndNewlines), schema: schema)
            }
            handle?.succeed()
            viewModel.lastSuccessMessage = "Storage parameters updated"
            await viewModel.reload()
        } catch {
            handle?.fail(error.localizedDescription)
            viewModel.lastError = error.localizedDescription
        }
    }
}
