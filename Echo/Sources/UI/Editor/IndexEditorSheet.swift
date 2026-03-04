import SwiftUI

struct IndexEditorSheet: View {
    @Binding var index: TableStructureEditorViewModel.IndexModel
    let availableColumns: [String]
    let onDelete: () -> Void
    let onCancelNew: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: Draft

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
                        .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .disabled(index == 0)
                .help("Move up")

                Button {
                    moveColumn(at: index, by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
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

    private func moveColumn(at index: Int, by offset: Int) {
        let newIndex = index + offset
        guard newIndex >= 0 && newIndex < draft.columns.count else { return }
        withAnimation {
            draft.columns.move(fromOffsets: IndexSet(integer: index), toOffset: newIndex > index ? newIndex + 1 : newIndex)
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
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }

    private var columnOptions: [String] {
        let current = draft.columns.map(\.name)
        let combined = Set(availableColumns + current)
        return combined.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var addableColumns: [String] {
        availableColumns.filter { name in
            !draft.columns.contains { $0.name == name }
        }.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func addColumn(named name: String) {
        draft.columns.append(.init(name: name, sortOrder: .ascending))
    }

    private func removeColumn(withID id: UUID) {
        draft.columns.removeAll { $0.id == id }
    }

    private func applyDraft() {
        index.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        index.isUnique = draft.isUnique
        index.filterCondition = draft.filterCondition.trimmingCharacters(in: .whitespacesAndNewlines)
        index.columns = draft.columns.map { column in
            TableStructureEditorViewModel.IndexModel.Column(name: column.name, sortOrder: column.sortOrder)
        }
    }

    private func cancelEditing() {
        if draft.isEditingExisting {
            dismiss()
        } else {
            dismiss()
            onCancelNew()
        }
    }

    struct Draft: Identifiable {
        struct Column: Identifiable {
            let id = UUID()
            var name: String
            var sortOrder: TableStructureEditorViewModel.IndexModel.Column.SortOrder
        }

        var id = UUID()
        var name: String
        var isUnique: Bool
        var filterCondition: String
        var columns: [Column]
        let isEditingExisting: Bool

        init(
            model: TableStructureEditorViewModel.IndexModel,
            availableColumns: [String]
        ) {
            self.name = model.name
            self.isUnique = model.isUnique
            self.filterCondition = model.filterCondition
            self.columns = model.columns.map { Column(name: $0.name, sortOrder: $0.sortOrder) }
            self.isEditingExisting = !model.isNew

            if columns.isEmpty {
                let initialName = model.columns.first?.name ?? availableColumns.first ?? ""
                if !initialName.isEmpty {
                    self.columns = [Column(name: initialName, sortOrder: .ascending)]
                }
            }
        }

        var canSave: Bool {
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !columns.isEmpty && columns.allSatisfy { !$0.name.isEmpty }
        }
    }
}
