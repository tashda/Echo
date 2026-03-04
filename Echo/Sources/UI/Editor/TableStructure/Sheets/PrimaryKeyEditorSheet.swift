import SwiftUI
import Foundation
#if os(macOS)
import AppKit
#endif

struct PrimaryKeyEditorSheet: View {
    @Binding var primaryKey: TableStructureEditorViewModel.PrimaryKeyModel
    let availableColumns: [String]
    let onDelete: () -> Void
    let onCancelNew: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: Draft

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
                generalSection
                columnsSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            toolbar
        }
        .frame(minWidth: 460, idealWidth: 500, minHeight: 400)
        .navigationTitle(draft.isEditingExisting ? "Edit Primary Key" : "New Primary Key")
    }

    private var generalSection: some View {
        Section {
            TextField("Constraint Name", text: $draft.name)
        } footer: {
            if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Name is required.")
                    .foregroundStyle(.red)
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
        } footer: {
            if draft.columns.isEmpty {
                Text("At least one column is required.")
                    .foregroundStyle(.red)
            } else if addableColumns.isEmpty {
                Text("All available columns are already included.")
            } else {
                Text("Columns use the order shown above.")
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

    private var toolbar: some View {
        HStack(spacing: 12) {
            if draft.isEditingExisting {
                Button("Delete Primary Key", role: .destructive) {
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
        primaryKey.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        primaryKey.columns = draft.columns.map { $0.name }
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
