import SwiftUI

/// A minimal sheet for creating a new SQL Server Agent job category.
struct NewAgentCategorySheet: View {
    @Binding var categoryName: String
    @Binding var errorMessage: String?
    let onCreate: () -> Void
    let onCancel: () -> Void

    private var isValid: Bool {
        !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("New Job Category") {
                    TextField("Name", text: $categoryName, prompt: Text("e.g. Database Maintenance"))
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Status.error)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                Button("Create") {
                    onCreate()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding(SpacingTokens.md2)
        }
        .frame(minWidth: 360, minHeight: 180)
    }
}
