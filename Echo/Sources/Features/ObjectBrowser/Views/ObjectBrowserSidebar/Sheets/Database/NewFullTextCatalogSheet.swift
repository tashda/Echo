import SwiftUI

struct NewFullTextCatalogSheet: View {
    let onSave: (String, Bool, Bool) async -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var isDefault = false
    @State private var accentSensitive = true

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        SheetLayout(
            title: "New Full-Text Catalog",
            icon: "text.magnifyingglass",
            subtitle: "Create a full-text catalog for text search indexing.",
            primaryAction: "Create",
            canSubmit: isFormValid,
            onSubmit: {
                await onSave(
                    name.trimmingCharacters(in: .whitespacesAndNewlines),
                    isDefault,
                    accentSensitive
                )
            },
            onCancel: { onCancel() }
        ) {
            Form {
                Section("New Full-Text Catalog") {
                    PropertyRow(title: "Catalog Name") {
                        TextField("", text: $name, prompt: Text("e.g. FT_Catalog"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Default Catalog") {
                        Toggle("", isOn: $isDefault)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                    PropertyRow(title: "Accent Sensitive") {
                        Toggle("", isOn: $accentSensitive)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 380, idealWidth: 420, minHeight: 220)
    }
}
