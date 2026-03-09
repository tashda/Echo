import SwiftUI

extension IndexEditorSheet {
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

    func applyDraft() {
        index.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        index.isUnique = draft.isUnique
        index.filterCondition = draft.filterCondition.trimmingCharacters(in: .whitespacesAndNewlines)
        index.columns = draft.columns.map { column in
            TableStructureEditorViewModel.IndexModel.Column(name: column.name, sortOrder: column.sortOrder)
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

    var columnOptions: [String] {
        let current = draft.columns.map(\.name)
        let combined = Set(availableColumns + current)
        return combined.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var addableColumns: [String] {
        availableColumns.filter { name in
            !draft.columns.contains { $0.name == name }
        }.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func addColumn(named name: String) {
        draft.columns.append(.init(name: name, sortOrder: .ascending))
    }

    func removeColumn(withID id: UUID) {
        draft.columns.removeAll { $0.id == id }
    }

    func moveColumn(at index: Int, by offset: Int) {
        let newIndex = index + offset
        guard newIndex >= 0 && newIndex < draft.columns.count else { return }
        withAnimation {
            draft.columns.move(fromOffsets: IndexSet(integer: index), toOffset: newIndex > index ? newIndex + 1 : newIndex)
        }
    }
}
