import SwiftUI

extension IndexEditorSheet {
    struct Draft: Identifiable {
        struct Column: Identifiable {
            let id = UUID()
            var name: String
            var sortOrder: TableStructureEditorViewModel.IndexModel.Column.SortOrder
            var isIncluded: Bool
        }

        var id = UUID()
        var name: String
        var isUnique: Bool
        var filterCondition: String
        var indexType: String
        var columns: [Column]
        let isEditingExisting: Bool

        init(
            model: TableStructureEditorViewModel.IndexModel,
            availableColumns: [String]
        ) {
            self.name = model.name
            self.isUnique = model.isUnique
            self.filterCondition = model.filterCondition
            self.indexType = model.indexType
            self.columns = model.columns.map { Column(name: $0.name, sortOrder: $0.sortOrder, isIncluded: $0.isIncluded) }
            self.isEditingExisting = !model.isNew

            if columns.isEmpty {
                let initialName = model.columns.first?.name ?? availableColumns.first ?? ""
                if !initialName.isEmpty {
                    self.columns = [Column(name: initialName, sortOrder: .ascending, isIncluded: false)]
                }
            }
        }

        var canSave: Bool {
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !columns.isEmpty && columns.allSatisfy { !$0.name.isEmpty }
        }
    }

    func draftColumnBinding(for columnID: UUID) -> Binding<Draft.Column> {
        guard let index = draft.columns.firstIndex(where: { $0.id == columnID }) else {
            fatalError("Column not found")
        }
        return $draft.columns[index]
    }

    func applyDraft() {
        let updatedIndex = TableStructureEditorViewModel.IndexModel(
            original: index.original,
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            columns: draft.columns.map { column in
            TableStructureEditorViewModel.IndexModel.Column(name: column.name, sortOrder: column.sortOrder, isIncluded: column.isIncluded)
            },
            isUnique: draft.isUnique,
            filterCondition: draft.filterCondition.trimmingCharacters(in: .whitespacesAndNewlines),
            indexType: draft.indexType
        )

        if draft.isEditingExisting {
            index = updatedIndex
        } else {
            onSaveNew?(updatedIndex)
        }
    }

    func cancelEditing() {
        if draft.isEditingExisting {
            dismiss()
        } else {
            dismiss()
            onCancelNew()
        }
    }

    var addableColumns: [String] {
        availableColumns.filter { name in
            !draft.columns.contains { $0.name == name }
        }.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func addColumn(named name: String) {
        draft.columns.append(.init(name: name, sortOrder: .ascending, isIncluded: false))
    }

    func removeColumn(withID id: UUID) {
        draft.columns.removeAll { $0.id == id }
    }
}
