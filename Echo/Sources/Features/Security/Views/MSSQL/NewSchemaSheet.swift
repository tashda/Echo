import SwiftUI
import SQLServerKit

struct NewSchemaSheet: View {
    let viewModel: DatabaseSecurityViewModel
    let onComplete: () -> Void

    @State private var schemaName = ""
    @State private var authorization = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        !schemaName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("New Schema") {
                    PropertyRow(title: "Schema Name") {
                        TextField("", text: $schemaName, prompt: Text("e.g. reporting"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Authorization") {
                        TextField("", text: $authorization, prompt: Text("e.g. dbo (optional)"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            HStack(spacing: SpacingTokens.sm) {
                if let error = errorMessage {
                    Text(error)
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Status.error)
                        .lineLimit(1)
                }

                Spacer()

                Button("Cancel") { onComplete() }
                    .keyboardShortcut(.cancelAction)

                Button("Create") { Task { await submit() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isFormValid)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, SpacingTokens.md2)
            .padding(.vertical, SpacingTokens.sm2)
            .background(.bar)
        }
        .frame(minWidth: 380, idealWidth: 420, minHeight: 200)
        .navigationTitle("New Schema")
    }

    private func submit() async {
        let name = schemaName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        let auth = authorization.trimmingCharacters(in: .whitespacesAndNewlines)
        await viewModel.createSchema(name: name, authorization: auth.isEmpty ? nil : auth)

        if viewModel.schemas.contains(where: { $0.name == name }) {
            onComplete()
        } else {
            isSubmitting = false
            errorMessage = "Failed to create schema"
        }
    }
}
