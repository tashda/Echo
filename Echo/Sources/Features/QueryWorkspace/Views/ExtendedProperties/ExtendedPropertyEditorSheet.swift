import SwiftUI

struct ExtendedPropertyEditorSheet: View {
    @Bindable var viewModel: ExtendedPropertiesViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    PropertyRow(title: "Name") {
                        TextField("", text: nameBinding, prompt: Text("property_name"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .disabled(!isNew)
                    }

                    if let childName = viewModel.editingProperty?.childName {
                        PropertyRow(title: "Target") {
                            Text("\(viewModel.editingProperty?.childType ?? "COLUMN"): \(childName)")
                                .foregroundStyle(ColorTokens.Text.secondary)
                        }
                    }
                }

                Section("Value") {
                    TextEditor(text: valueBinding)
                        .font(TypographyTokens.standard.monospaced())
                        .frame(minHeight: 80, idealHeight: 120)
                        .scrollContentBackground(.hidden)
                        .overlay(alignment: .topLeading) {
                            if valueBinding.wrappedValue.isEmpty {
                                Text("Enter property value")
                                    .font(TypographyTokens.standard.monospaced())
                                    .foregroundStyle(ColorTokens.Text.tertiary)
                                    .padding(.top, SpacingTokens.xxs)
                                    .padding(.leading, SpacingTokens.xxs)
                                    .allowsHitTesting(false)
                            }
                        }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            toolbar
        }
        .frame(minWidth: 420, idealWidth: 460, minHeight: 300)
        .navigationTitle(isNew ? "Add Extended Property" : "Edit Extended Property")
    }

    private var toolbar: some View {
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
            .buttonStyle(.borderedProminent)
            .disabled(nameBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, SpacingTokens.md2)
        .padding(.vertical, SpacingTokens.sm2)
        .background(.bar)
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
