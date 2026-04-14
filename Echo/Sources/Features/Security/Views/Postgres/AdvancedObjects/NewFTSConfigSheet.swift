import SwiftUI
import PostgresKit

struct NewFTSConfigSheet: View {
    let viewModel: PostgresAdvancedObjectsViewModel
    let onComplete: () -> Void

    @State private var name = ""
    @State private var schema = "public"
    @State private var mode = Mode.parser
    @State private var parser = "default"
    @State private var copySource = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    enum Mode: String, CaseIterable {
        case parser = "Parser"
        case copy = "Copy From"
    }

    private var isFormValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !isSubmitting else { return false }
        switch mode {
        case .parser: return !parser.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .copy: return !copySource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var body: some View {
        SheetLayout(
            title: "New Text Search Configuration",
            icon: "magnifyingglass",
            subtitle: "Create a full-text search configuration.",
            primaryAction: "Create",
            canSubmit: isFormValid,
            isSubmitting: isSubmitting,
            errorMessage: errorMessage,
            onSubmit: { await submit() },
            onCancel: { onComplete() }
        ) {
            Form {
                Section("Configuration") {
                    PropertyRow(title: "Name") {
                        TextField("", text: $name, prompt: Text("e.g. my_english"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Schema") {
                        Picker("", selection: $schema) {
                            ForEach(viewModel.availableSchemas, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }

                Section("Source") {
                    PropertyRow(title: "Mode", info: "Choose whether to create from a text search parser or copy settings from an existing configuration.") {
                        Picker("", selection: $mode) {
                            ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }

                    if mode == .parser {
                        PropertyRow(title: "Parser", info: "The text search parser that tokenizes input text. PostgreSQL includes a built-in parser named 'default'. Custom parsers can be created as extensions.") {
                            Picker("", selection: $parser) {
                                Text("default").tag("default")
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }
                    } else {
                        PropertyRow(title: "Copy From", info: "An existing text search configuration to copy all settings from.") {
                            Picker("", selection: $copySource) {
                                Text("Select a configuration…").tag("")
                                ForEach(viewModel.ftsConfigs, id: \.name) { config in
                                    Text("\(config.schema).\(config.name)").tag("\(config.schema).\(config.name)")
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 480, idealWidth: 540, minHeight: 340)
    }

    private func submit() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        let parserVal = parser.trimmingCharacters(in: .whitespacesAndNewlines)
        let copyVal = copySource.trimmingCharacters(in: .whitespacesAndNewlines)

        await viewModel.createFTSConfig(
            name: trimmedName,
            schema: schema,
            parser: mode == .parser && !parserVal.isEmpty ? parserVal : nil,
            copySource: mode == .copy && !copyVal.isEmpty ? copyVal : nil
        )

        if viewModel.ftsConfigs.contains(where: { $0.name == trimmedName }) {
            onComplete()
        } else {
            isSubmitting = false
            errorMessage = "Failed to create FTS configuration"
        }
    }
}
