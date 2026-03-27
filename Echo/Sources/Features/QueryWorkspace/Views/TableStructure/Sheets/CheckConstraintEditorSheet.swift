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
        SheetLayout(
            title: draft.isEditingExisting ? "Edit Check Constraint" : "New Check Constraint",
            icon: "checkmark.shield",
            subtitle: draft.isEditingExisting ? "Modify the check constraint expression." : "Add a boolean expression that rows must satisfy.",
            primaryAction: "Save",
            canSubmit: draft.canSave,
            onSubmit: {
                applyDraftChanges()
                dismiss()
            },
            onCancel: {
                dismiss()
                cancelIfNew()
            },
            destructiveAction: draft.isEditingExisting ? "Delete Constraint" : nil,
            onDestructive: draft.isEditingExisting ? {
                dismiss()
                onDelete()
            } : nil
        ) {
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
        }
        .frame(minWidth: 420, idealWidth: 460, minHeight: 300)
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
