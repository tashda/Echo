import SwiftUI
import Foundation

extension ForeignKeyEditorSheet {

    func applyDraftToModel() {
        foreignKey.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        foreignKey.columns = draft.columns.map { $0.name }
        foreignKey.referencedSchema = draft.referencedSchema.trimmingCharacters(in: .whitespacesAndNewlines)
        foreignKey.referencedTable = draft.referencedTable.trimmingCharacters(in: .whitespacesAndNewlines)
        foreignKey.referencedColumns = draft.referencedColumns

        let updateValue = draft.onUpdate.trimmingCharacters(in: .whitespacesAndNewlines)
        foreignKey.onUpdate = updateValue.isEmpty || updateValue == ForeignKeyAction.noAction.rawValue ? nil : updateValue

        let deleteValue = draft.onDelete.trimmingCharacters(in: .whitespacesAndNewlines)
        foreignKey.onDelete = deleteValue.isEmpty || deleteValue == ForeignKeyAction.noAction.rawValue ? nil : deleteValue
    }

    func draftBinding(for columnID: UUID) -> Binding<Draft.Column> {
        guard let index = draft.columns.firstIndex(where: { $0.id == columnID }) else {
            fatalError("Column not found")
        }
        return $draft.columns[index]
    }

    func draftColumnOptions(for columnID: UUID) -> [String] {
        let selectedByOthers = Set(draft.columns.filter { $0.id != columnID }.map { $0.name })
        let options = availableColumns.filter { !selectedByOthers.contains($0) }
        if let current = draft.columns.first(where: { $0.id == columnID })?.name,
           !current.isEmpty,
           !options.contains(current) {
            return (options + [current]).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        }
        return options.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var computedAddableColumns: [String] {
        availableColumns.filter { name in
            !draft.columns.contains { $0.name == name }
        }.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func addDraftColumn(named name: String) {
        draft.columns.append(.init(name: name))
    }

    func removeDraftColumn(withID id: UUID) {
        draft.columns.removeAll { $0.id == id }
    }

    func moveDraftColumn(at index: Int, by offset: Int) {
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
            self.onUpdate = model.onUpdate ?? ForeignKeyAction.noAction.rawValue
            self.onDelete = model.onDelete ?? ForeignKeyAction.noAction.rawValue
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
