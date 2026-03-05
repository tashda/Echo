import SwiftUI

struct IndexEditorSheet: View {
    @Binding var index: TableStructureEditorViewModel.IndexModel
    let availableColumns: [String]
    let onDelete: () -> Void
    let onCancelNew: () -> Void

    @Environment(\.dismiss) internal var dismiss
    @State internal var draft: Draft

    init(
        index: Binding<TableStructureEditorViewModel.IndexModel>,
        availableColumns: [String],
        onDelete: @escaping () -> Void,
        onCancelNew: @escaping () -> Void
    ) {
        self._index = index
        self.availableColumns = availableColumns
        self.onDelete = onDelete
        self.onCancelNew = onCancelNew
        _draft = State(initialValue: Draft(model: index.wrappedValue, availableColumns: availableColumns))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Form {
                    generalSection
                    columnsSection
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            }

            Divider()

            toolbar
        }
        .frame(minWidth: 500, idealWidth: 540, minHeight: 420)
        .navigationTitle(draft.isEditingExisting ? "Edit Index" : "New Index")
    }

    private var generalSection: some View {
        Section {
            LabeledContent("Name") {
                TextField("Index name", text: $draft.name)
            }

            Toggle("Unique", isOn: $draft.isUnique)

            LabeledContent("Filter") {
                TextField("WHERE status = 'active'", text: $draft.filterCondition, axis: .vertical)
                    .lineLimit(3...6)
                    .multilineTextAlignment(.trailing)
            }
        } header: {
            Text("General")
        } footer: {
            if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Name is required.")
                    .foregroundStyle(.red)
            } else {
                Text("Filter condition allows creating partial indexes.")
            }
        }
    }

    private var columnsSection: some View {
        Section {
            ForEach(Array(draft.columns.enumerated()), id: \.element.id) { index, column in
                columnRow(for: binding(for: column.id), index: index)
            }

            HStack {
                Menu {
                    ForEach(addableColumns, id: \.self) { columnName in
                        Button(columnName) {
                            addColumn(named: columnName)
                        }
                    }
                } label: {
                    Label("Add Column", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .disabled(addableColumns.isEmpty)

                Spacer()
            }
        } header: {
            Text("Columns")
        } footer: {
            if draft.columns.isEmpty {
                Text("At least one column is required.")
                    .foregroundStyle(.red)
            } else if addableColumns.isEmpty {
                Text("All available columns are already included.")
            } else {
                Text("Columns are indexed in the order shown above. Use arrows to reorder.")
            }
        }
    }

    private func binding(for columnID: UUID) -> Binding<Draft.Column> {
        guard let index = draft.columns.firstIndex(where: { $0.id == columnID }) else {
            fatalError("Column not found")
        }
        return $draft.columns[index]
    }

    private func columnRow(for column: Binding<Draft.Column>, index: Int) -> some View {
        let columnID = column.wrappedValue.id

        return HStack(spacing: 12) {
            VStack(spacing: 2) {
                Button {
                    moveColumn(at: index, by: -1)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(TypographyTokens.label)
                }
                .buttonStyle(.borderless)
                .disabled(index == 0)
                .help("Move up")

                Button {
                    moveColumn(at: index, by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(TypographyTokens.label)
                }
                .buttonStyle(.borderless)
                .disabled(index == draft.columns.count - 1)
                .help("Move down")
            }
            .frame(width: 20)

            Picker("", selection: column.name) {
                ForEach(columnOptions, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: 200)

            Picker("", selection: column.sortOrder) {
                Text("Ascending").tag(TableStructureEditorViewModel.IndexModel.Column.SortOrder.ascending)
                Text("Descending").tag(TableStructureEditorViewModel.IndexModel.Column.SortOrder.descending)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: 180)

            Spacer()

            Button(role: .destructive) {
                removeColumn(withID: columnID)
            } label: {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.borderless)
            .disabled(draft.columns.count <= 1)
            .help("Remove column")
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            if draft.isEditingExisting {
                Button("Delete Index", role: .destructive) {
                    dismiss()
                    onDelete()
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            Button("Cancel") {
                cancelEditing()
            }
            .keyboardShortcut(.cancelAction)

            Button("Save") {
                applyDraft()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!draft.canSave)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, SpacingTokens.md2)
        .padding(.vertical, SpacingTokens.sm2)
        .background(.ultraThinMaterial)
    }
}
