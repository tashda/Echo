import SwiftUI
import PostgresKit

struct NewForeignServerSheet: View {
    let viewModel: PostgresAdvancedObjectsViewModel
    let onComplete: () -> Void

    @State private var name = ""
    @State private var serverType = ""
    @State private var version = ""
    @State private var fdwName = ""
    @State private var optionsText = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !fdwName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !isSubmitting
    }

    var body: some View {
        SheetLayout(
            title: "New Foreign Server",
            icon: "server.rack",
            subtitle: "Register a remote server via a foreign data wrapper.",
            primaryAction: "Create",
            canSubmit: isFormValid,
            isSubmitting: isSubmitting,
            errorMessage: errorMessage,
            onSubmit: { await submit() },
            onCancel: { onComplete() }
        ) {
            Form {
                Section("Server") {
                    PropertyRow(title: "Name") {
                        TextField("", text: $name, prompt: Text("e.g. remote_pg"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Type", info: "An optional server type string. Some foreign data wrappers use this to determine connection behavior.") {
                        TextField("", text: $serverType, prompt: Text("e.g. postgresql"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Version", info: "An optional version string for the foreign server.") {
                        TextField("", text: $version, prompt: Text("e.g. 16.0"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Connection") {
                    PropertyRow(title: "Foreign Data Wrapper") {
                        if viewModel.fdws.isEmpty {
                            TextField("", text: $fdwName, prompt: Text("e.g. postgres_fdw"))
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                        } else {
                            Picker("", selection: $fdwName) {
                                Text("Select FDW").tag("")
                                ForEach(viewModel.fdws, id: \.name) { Text($0.name).tag($0.name) }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }
                    }
                    PropertyRow(title: "Options", info: "Comma-separated key=value options specific to the foreign data wrapper, e.g. host=myhost, port=5432, dbname=mydb.") {
                        TextField("", text: $optionsText, prompt: Text("e.g. host=remote port=5432 dbname=mydb"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 480, idealWidth: 540, minHeight: 360)
    }

    private func submit() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFDW = fdwName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedFDW.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        let typeVal = serverType.trimmingCharacters(in: .whitespacesAndNewlines)
        let versionVal = version.trimmingCharacters(in: .whitespacesAndNewlines)
        let options = parseOptions(optionsText)

        await viewModel.createForeignServer(
            name: trimmedName,
            type: typeVal.isEmpty ? nil : typeVal,
            version: versionVal.isEmpty ? nil : versionVal,
            fdwName: trimmedFDW,
            options: options
        )

        if viewModel.foreignServers.contains(where: { $0.name == trimmedName }) {
            onComplete()
        } else {
            isSubmitting = false
            errorMessage = "Failed to create foreign server"
        }
    }

    private func parseOptions(_ text: String) -> [String: String]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var result: [String: String] = [:]
        for pair in trimmed.split(separator: " ") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 { result[String(parts[0])] = String(parts[1]) }
        }
        return result.isEmpty ? nil : result
    }
}
