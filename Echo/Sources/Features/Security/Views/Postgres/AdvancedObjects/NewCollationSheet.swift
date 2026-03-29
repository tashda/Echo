import SwiftUI
import PostgresKit

struct NewCollationSheet: View {
    let viewModel: PostgresAdvancedObjectsViewModel
    let onComplete: () -> Void

    @State private var name = ""
    @State private var schema = "public"
    @State private var locale = ""
    @State private var provider = "libc"
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let providers = ["libc", "icu"]

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !locale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !isSubmitting
    }

    var body: some View {
        SheetLayout(
            title: "New Collation",
            icon: "textformat",
            subtitle: "Define a custom text sorting and comparison rule.",
            primaryAction: "Create",
            canSubmit: isFormValid,
            isSubmitting: isSubmitting,
            errorMessage: errorMessage,
            onSubmit: { await submit() },
            onCancel: { onComplete() }
        ) {
            Form {
                Section("Collation") {
                    PropertyRow(title: "Name") {
                        TextField("", text: $name, prompt: Text("e.g. french_ci"))
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
                    PropertyRow(title: "Locale", info: "The operating system locale identifier, e.g. en_US.utf8, fr_FR.utf8.") {
                        TextField("", text: $locale, prompt: Text("e.g. fr_FR.utf8"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Provider", info: "The collation provider. libc uses OS-level collation, icu uses the ICU library for Unicode-aware sorting.") {
                        Picker("", selection: $provider) {
                            ForEach(providers, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 480, idealWidth: 540, minHeight: 320)
    }

    private func submit() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocale = locale.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedLocale.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        await viewModel.createCollation(
            name: trimmedName,
            schema: schema,
            locale: trimmedLocale,
            provider: provider
        )

        if viewModel.collations.contains(where: { $0.name == trimmedName }) {
            onComplete()
        } else {
            isSubmitting = false
            errorMessage = "Failed to create collation"
        }
    }
}
