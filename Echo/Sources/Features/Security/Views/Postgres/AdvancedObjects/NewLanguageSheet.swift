import SwiftUI
import PostgresKit

struct NewLanguageSheet: View {
    let viewModel: PostgresAdvancedObjectsViewModel
    let onComplete: () -> Void

    @State private var name = ""
    @State private var isTrusted = false
    @State private var handler = ""
    @State private var validator = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !isSubmitting
    }

    var body: some View {
        SheetLayout(
            title: "New Language",
            icon: "globe",
            subtitle: "Register a new procedural language.",
            primaryAction: "Create",
            canSubmit: isFormValid,
            isSubmitting: isSubmitting,
            errorMessage: errorMessage,
            onSubmit: { await submit() },
            onCancel: { onComplete() }
        ) {
            Form {
                Section("Language") {
                    PropertyRow(title: "Name") {
                        TextField("", text: $name, prompt: Text("e.g. plpython3u"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Trusted", info: "Trusted languages restrict users from accessing the file system or other server internals.") {
                        Toggle("", isOn: $isTrusted)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }

                Section {
                    PropertyRow(title: "Handler", info: "The function that executes code written in this language. Leave empty for built-in SQL-based languages.") {
                        TextField("", text: $handler, prompt: Text("e.g. plpython3_call_handler"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Validator", info: "An optional function that validates source code when a function is created in this language.") {
                        TextField("", text: $validator, prompt: Text("e.g. plpython3_validator"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Handlers")
                } footer: {
                    Text("Leave handler empty for built-in languages.")
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

        let trimmedHandler = handler.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedValidator = validator.trimmingCharacters(in: .whitespacesAndNewlines)

        await viewModel.createLanguage(
            name: trimmedName,
            trusted: isTrusted,
            handler: trimmedHandler.isEmpty ? nil : trimmedHandler,
            validator: trimmedValidator.isEmpty ? nil : trimmedValidator
        )

        if viewModel.languages.contains(where: { $0.name == trimmedName }) {
            onComplete()
        } else {
            isSubmitting = false
            errorMessage = "Failed to create language"
        }
    }
}
