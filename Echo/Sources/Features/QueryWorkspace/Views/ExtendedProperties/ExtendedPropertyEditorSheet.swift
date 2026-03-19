import SwiftUI

struct ExtendedPropertyEditorSheet: View {
    @Bindable var viewModel: ExtendedPropertiesViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: SpacingTokens.md) {
            Text(isNew ? "Add Extended Property" : "Edit Extended Property")
                .font(TypographyTokens.prominent.weight(.semibold))

            Form {
                TextField("Name", text: nameBinding)
                    .disabled(!isNew)

                if let childName = viewModel.editingProperty?.childName {
                    LabeledContent("Target") {
                        Text("\(viewModel.editingProperty?.childType ?? "COLUMN"): \(childName)")
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    Text("Value")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                    TextEditor(text: valueBinding)
                        .font(TypographyTokens.standard)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .padding(SpacingTokens.xxs)
                        .background(
                            RoundedRectangle(cornerRadius: SpacingTokens.xxs, style: .continuous)
                                .fill(ColorTokens.Background.secondary)
                        )
                }
            }
            .formStyle(.grouped)

            HStack(spacing: SpacingTokens.sm) {
                Spacer()
                Button("Cancel") {
                    viewModel.cancelEdit()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(isNew ? "Add" : "Save") {
                    Task {
                        await viewModel.save()
                        if viewModel.editingProperty == nil {
                            dismiss()
                        }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(nameBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(SpacingTokens.lg)
        .frame(minWidth: 400, minHeight: 300)
    }

    private var isNew: Bool {
        viewModel.editingProperty?.isNew ?? true
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { viewModel.editingProperty?.name ?? "" },
            set: { viewModel.editingProperty?.name = $0 }
        )
    }

    private var valueBinding: Binding<String> {
        Binding(
            get: { viewModel.editingProperty?.value ?? "" },
            set: { viewModel.editingProperty?.value = $0 }
        )
    }
}
