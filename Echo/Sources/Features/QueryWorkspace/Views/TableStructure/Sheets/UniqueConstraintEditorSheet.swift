import SwiftUI

struct UniqueConstraintEditorSheet: View {
    @Binding var constraint: TableStructureEditorViewModel.UniqueConstraintModel
    let availableColumns: [String]
    let databaseType: DatabaseType
    let onDelete: () -> Void
    let onCancelNew: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State var draft: Draft

    init(
        constraint: Binding<TableStructureEditorViewModel.UniqueConstraintModel>,
        availableColumns: [String],
        databaseType: DatabaseType,
        onDelete: @escaping () -> Void,
        onCancelNew: @escaping () -> Void
    ) {
        self._constraint = constraint
        self.availableColumns = availableColumns
        self.databaseType = databaseType
        self.onDelete = onDelete
        self.onCancelNew = onCancelNew
        _draft = State(initialValue: Draft(model: constraint.wrappedValue, availableColumns: availableColumns))
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    PropertyRow(title: "Constraint Name") {
                        TextField("", text: $draft.name, prompt: Text("UQ_table_columns"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }

                if databaseType == .postgresql {
                    Section("Deferrable") {
                        PropertyRow(
                            title: "Deferrable",
                            info: "A deferrable constraint can be checked at the end of a transaction instead of immediately. This allows temporary violations during multi-statement operations."
                        ) {
                            Toggle("", isOn: $draft.isDeferrable)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .onChange(of: draft.isDeferrable) { _, newValue in
                                    if !newValue { draft.isInitiallyDeferred = false }
                                }
                        }
                        if draft.isDeferrable {
                            PropertyRow(title: "Initially Deferred") {
                                Toggle("", isOn: $draft.isInitiallyDeferred)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                            }
                        }
                    }
                }

                Section("Columns") {
                    ColumnSelectionList(
                        columns: $draft.columns,
                        displayMode: .text,
                        availableColumns: availableColumns,
                        minColumns: 0
                    )
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            toolbar
        }
        .frame(minWidth: 420, idealWidth: 460, minHeight: 340)
        .navigationTitle(draft.isEditingExisting ? "Edit Unique Constraint" : "New Unique Constraint")
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
        typealias Column = ColumnSelectionList.Column

        var name: String
        var columns: [Column]
        var isDeferrable: Bool
        var isInitiallyDeferred: Bool
        let isEditingExisting: Bool

        init(model: TableStructureEditorViewModel.UniqueConstraintModel, availableColumns: [String]) {
            self.name = model.name
            self.columns = model.columns.map { .init(name: $0) }
            self.isDeferrable = model.isDeferrable
            self.isInitiallyDeferred = model.isInitiallyDeferred
            self.isEditingExisting = !model.isNew

            // New constraints start with no columns selected — user adds from the menu
        }

        var canSave: Bool {
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !columns.isEmpty &&
                columns.allSatisfy { !$0.name.isEmpty }
        }
    }
}
