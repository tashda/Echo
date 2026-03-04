import SwiftUI
import Foundation
#if os(macOS)
import AppKit
#endif

struct ForeignKeyEditorSheet: View {
    @Binding var foreignKey: TableStructureEditorViewModel.ForeignKeyModel
    let availableColumns: [String]
    let onDelete: () -> Void
    let onCancelNew: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: Draft

    init(
        foreignKey: Binding<TableStructureEditorViewModel.ForeignKeyModel>,
        availableColumns: [String],
        onDelete: @escaping () -> Void,
        onCancelNew: @escaping () -> Void
    ) {
        self._foreignKey = foreignKey
        self.availableColumns = availableColumns
        self.onDelete = onDelete
        self.onCancelNew = onCancelNew
        _draft = State(initialValue: Draft(model: foreignKey.wrappedValue, availableColumns: availableColumns))
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                generalSection
                columnsSection
                referenceSection
                actionsSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            toolbar
        }
        .frame(minWidth: 520, idealWidth: 560, minHeight: 460)
        .navigationTitle(draft.isEditingExisting ? "Edit Foreign Key" : "New Foreign Key")
    }

    private var generalSection: some View {
        Section {
            TextField("Constraint Name", text: $draft.name)

            HStack {
                TextField("Schema", text: $draft.referencedSchema)
                TextField("Table", text: $draft.referencedTable)
            }
        } header: {
            Text("General")
        } footer: {
            VStack(alignment: .leading, spacing: 2) {
                if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Name is required.")
                        .foregroundStyle(.red)
                }
                if draft.referencedTable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Referenced table is required.")
                        .foregroundStyle(.red)
                }
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
                    ForEach(addableColumns, id: \.self) { name in
                        Button(name) {
                            addColumn(named: name)
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
                Text("At least one local column is required.")
                    .foregroundStyle(.red)
            } else if addableColumns.isEmpty {
                Text("All columns are already included.")
            } else {
                Text("Order matches the referenced columns below.")
            }
        }
    }

    private func columnRow(for column: Binding<Draft.Column>, index: Int) -> some View {
        let columnID = column.wrappedValue.id
        return HStack(spacing: 12) {
            VStack(spacing: 2) {
                Button {
                    moveColumn(at: index, by: -1)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.borderless)
                .disabled(index == 0)

                Button {
                    moveColumn(at: index, by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.borderless)
                .disabled(index == draft.columns.count - 1)
            }
            .frame(width: 24)

            Picker("", selection: column.name) {
                ForEach(columnOptions(for: columnID), id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)

            Button(role: .destructive) {
                removeColumn(withID: columnID)
            } label: {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.borderless)
            .disabled(draft.columns.count <= 1)
        }
    }

    private var referenceSection: some View {
        Section {
            TextField("Referenced Columns", text: $draft.referencedColumnsInput)
        } header: {
            Text("References")
        } footer: {
            VStack(alignment: .leading, spacing: 2) {
                Text("Separate names with commas in the same order as local columns.")
                if draft.referencedColumnsMismatch {
                    Text("Column counts do not match.")
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var actionsSection: some View {
        Section {
            TextField("ON UPDATE", text: $draft.onUpdate)
            TextField("ON DELETE", text: $draft.onDelete)
        } header: {
            Text("Actions")
        } footer: {
            Text("Leave blank to use database defaults.")
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            if draft.isEditingExisting {
                Button("Delete Foreign Key", role: .destructive) {
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
            }
            .buttonStyle(.borderedProminent)
            .disabled(!draft.canSave)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func applyDraft() {
        foreignKey.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        foreignKey.columns = draft.columns.map { $0.name }
        foreignKey.referencedSchema = draft.referencedSchema.trimmingCharacters(in: .whitespacesAndNewlines)
        foreignKey.referencedTable = draft.referencedTable.trimmingCharacters(in: .whitespacesAndNewlines)
        foreignKey.referencedColumns = draft.referencedColumns

        let updateTrimmed = draft.onUpdate.trimmingCharacters(in: .whitespacesAndNewlines)
        foreignKey.onUpdate = updateTrimmed.isEmpty ? nil : updateTrimmed

        let deleteTrimmed = draft.onDelete.trimmingCharacters(in: .whitespacesAndNewlines)
        foreignKey.onDelete = deleteTrimmed.isEmpty ? nil : deleteTrimmed

        dismiss()
    }

    private func cancelEditing() {
        dismiss()
        if !draft.isEditingExisting {
            onCancelNew()
        }
    }

    private func binding(for columnID: UUID) -> Binding<Draft.Column> {
        guard let index = draft.columns.firstIndex(where: { $0.id == columnID }) else {
            fatalError("Column not found")
        }
        return $draft.columns[index]
    }

    private func columnOptions(for columnID: UUID) -> [String] {
        let selectedByOthers = Set(draft.columns.filter { $0.id != columnID }.map { $0.name })
        let options = availableColumns.filter { !selectedByOthers.contains($0) }
        if let current = draft.columns.first(where: { $0.id == columnID })?.name,
           !current.isEmpty,
           !options.contains(current) {
            return (options + [current]).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        }
        return options.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var addableColumns: [String] {
        availableColumns.filter { name in
            !draft.columns.contains { $0.name == name }
        }.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func addColumn(named name: String) {
        draft.columns.append(.init(name: name))
    }

    private func removeColumn(withID id: UUID) {
        draft.columns.removeAll { $0.id == id }
    }

    private func moveColumn(at index: Int, by offset: Int) {
        let newIndex = index + offset
        guard newIndex >= 0 && newIndex < draft.columns.count else { return }
        withAnimation {
            draft.columns.move(fromOffsets: IndexSet(integer: index), toOffset: newIndex > index ? newIndex + 1 : newIndex)
        }
    }

    private struct Draft {
        struct Column: Identifiable {
            let id = UUID()
            var name: String
        }

        var name: String
        var referencedSchema: String
        var referencedTable: String
        var columns: [Column]
        var referencedColumnsInput: String
        var onUpdate: String
        var onDelete: String
        let isEditingExisting: Bool

        init(
            model: TableStructureEditorViewModel.ForeignKeyModel,
            availableColumns: [String]
        ) {
            self.name = model.name
            self.referencedSchema = model.referencedSchema
            self.referencedTable = model.referencedTable
            self.columns = model.columns.map { Column(name: $0) }
            self.referencedColumnsInput = model.referencedColumns.joined(separator: ", ")
            self.onUpdate = model.onUpdate ?? ""
            self.onDelete = model.onDelete ?? ""
            self.isEditingExisting = model.original != nil

            if columns.isEmpty, let first = availableColumns.first {
                self.columns = [Column(name: first)]
            }
        }

        var referencedColumns: [String] {
            referencedColumnsInput
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        var referencedColumnsMismatch: Bool {
            !columns.isEmpty && referencedColumns.count != columns.count
        }

        var canSave: Bool {
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !referencedTable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !columns.isEmpty &&
                columns.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
    }
}
