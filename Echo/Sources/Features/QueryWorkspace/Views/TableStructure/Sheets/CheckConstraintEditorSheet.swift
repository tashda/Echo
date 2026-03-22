import SwiftUI

struct CheckConstraintEditorSheet: View {
    @Binding var constraint: TableStructureEditorViewModel.CheckConstraintModel
    let onDelete: () -> Void
    let onCancelNew: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State var draft: Draft

    init(
        constraint: Binding<TableStructureEditorViewModel.CheckConstraintModel>,
        onDelete: @escaping () -> Void,
        onCancelNew: @escaping () -> Void
    ) {
        self._constraint = constraint
        self.onDelete = onDelete
        self.onCancelNew = onCancelNew
        _draft = State(initialValue: Draft(model: constraint.wrappedValue))
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    PropertyRow(title: "Constraint Name") {
                        TextField("", text: $draft.name, prompt: Text("CK_table_column"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Expression") {
                    TextEditor(text: $draft.expression)
                        .font(TypographyTokens.standard.monospaced())
                        .frame(minHeight: 80, idealHeight: 120)
                        .scrollContentBackground(.hidden)
                        .overlay(alignment: .topLeading) {
                            if draft.expression.isEmpty {
                                Text("e.g. age >= 0")
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
        .navigationTitle(draft.isEditingExisting ? "Edit Check Constraint" : "New Check Constraint")
    }

    private var toolbar: some View {
        HStack(spacing: SpacingTokens.sm) {
            if draft.isEditingExisting {
                Button("Delete Constraint", role: .destructive) {
                    dismiss()
                    onDelete()
                }
                .buttonStyle(.bordered)
                .tint(ColorTokens.Status.error)
            }

            Spacer()

            Button("Cancel") {
                dismiss()
                cancelIfNew()
            }
            .keyboardShortcut(.cancelAction)

            Button("Save") {
                applyDraftChanges()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!draft.canSave)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, SpacingTokens.md2)
        .padding(.vertical, SpacingTokens.sm2)
        .background(.bar)
    }

    struct Draft {
        var name: String
        var expression: String
        let isEditingExisting: Bool

        init(model: TableStructureEditorViewModel.CheckConstraintModel) {
            self.name = model.name
            self.expression = model.expression
            self.isEditingExisting = !model.isNew
        }

        var canSave: Bool {
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !expression.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
