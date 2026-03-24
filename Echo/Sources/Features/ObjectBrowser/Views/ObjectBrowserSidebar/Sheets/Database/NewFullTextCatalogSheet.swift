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
        VStack(spacing: 0) {
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

            Divider()

            HStack(spacing: SpacingTokens.sm) {
                Spacer()

                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)

                Button("Create") {
                    Task {
                        await onSave(
                            name.trimmingCharacters(in: .whitespacesAndNewlines),
                            isDefault,
                            accentSensitive
                        )
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isFormValid)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, SpacingTokens.md2)
            .padding(.vertical, SpacingTokens.sm2)
            .background(.bar)
        }
        .frame(minWidth: 380, idealWidth: 420, minHeight: 220)
        .navigationTitle("New Full-Text Catalog")
    }
}
