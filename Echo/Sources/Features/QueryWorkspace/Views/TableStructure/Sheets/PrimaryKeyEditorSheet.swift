import SwiftUI

struct PrimaryKeyEditorSheet: View {
    @Binding var primaryKey: TableStructureEditorViewModel.PrimaryKeyModel
    let availableColumns: [String]
    let onDelete: () -> Void
    let onCancelNew: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State var draft: Draft
    @State private var hoveredColumnID: UUID?

    init(
        primaryKey: Binding<TableStructureEditorViewModel.PrimaryKeyModel>,
        availableColumns: [String],
        onDelete: @escaping () -> Void,
        onCancelNew: @escaping () -> Void
    ) {
        self._primaryKey = primaryKey
        self.availableColumns = availableColumns
        self.onDelete = onDelete
        self.onCancelNew = onCancelNew
        _draft = State(initialValue: Draft(model: primaryKey.wrappedValue, availableColumns: availableColumns))
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    LabeledContent("Constraint Name") {
                        TextField("", text: $draft.name)
                    }
                }

                Section("Columns") {
                    ForEach(Array(draft.columns.enumerated()), id: \.element.id) { _, column in
                        primaryKeyColumnRow(for: bindingForColumn(column.id))
                    }
                    .onMove { from, to in
                        draft.columns.move(fromOffsets: from, toOffset: to)
                    }

                    Menu {
                        ForEach(computedAddableColumns, id: \.self) { name in
                            Button(name) {
                                addDraftColumn(named: name)
                            }
                        }
                    } label: {
                        Label("Add Column", systemImage: "plus")
                    }
                    .menuStyle(.borderlessButton)
                    .disabled(computedAddableColumns.isEmpty)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            toolbar
        }
        .frame(minWidth: 420, idealWidth: 460, minHeight: 340)
        .navigationTitle(draft.isEditingExisting ? "Edit Primary Key" : "New Primary Key")
    }

    private func primaryKeyColumnRow(for column: Binding<Draft.Column>) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "line.3.horizontal")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)

            Text(column.wrappedValue.name)
                .font(TypographyTokens.standard)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(role: .destructive) {
                removeDraftColumn(withID: column.wrappedValue.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(hoveredColumnID == column.wrappedValue.id ? ColorTokens.Status.error : ColorTokens.Text.secondary)
            }
            .buttonStyle(.borderless)
            .help("Remove column")
            .disabled(draft.columns.count <= 1)
            .onHover { isHovered in
                hoveredColumnID = isHovered ? column.wrappedValue.id : nil
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: SpacingTokens.sm) {
            if draft.isEditingExisting {
                Button("Delete Primary Key", role: .destructive) {
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
        struct Column: Identifiable {
            let id = UUID()
            var name: String
        }

        var name: String
        var columns: [Column]
        let isEditingExisting: Bool

        init(model: TableStructureEditorViewModel.PrimaryKeyModel, availableColumns: [String]) {
            self.name = model.name
            self.columns = model.columns.map { .init(name: $0) }
            self.isEditingExisting = model.original != nil

            if columns.isEmpty, let first = availableColumns.first {
                self.columns = [.init(name: first)]
            }
        }

        var canSave: Bool {
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !columns.isEmpty &&
                columns.allSatisfy { !$0.name.isEmpty }
        }
    }
}
