import SwiftUI
import Foundation

extension ForeignKeyEditorSheet {

    func applyDraftToModel() {
        foreignKey.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        foreignKey.columns = draft.mappings.map(\.localColumn)
        foreignKey.referencedSchema = draft.referencedSchema.trimmingCharacters(in: .whitespacesAndNewlines)
        foreignKey.referencedTable = draft.referencedTable.trimmingCharacters(in: .whitespacesAndNewlines)
        foreignKey.referencedColumns = draft.mappings.map {
            $0.referencedColumn.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let updateValue = draft.onUpdate.trimmingCharacters(in: .whitespacesAndNewlines)
        foreignKey.onUpdate = updateValue.isEmpty || updateValue == ForeignKeyAction.noAction.rawValue ? nil : updateValue

        let deleteValue = draft.onDelete.trimmingCharacters(in: .whitespacesAndNewlines)
        foreignKey.onDelete = deleteValue.isEmpty || deleteValue == ForeignKeyAction.noAction.rawValue ? nil : deleteValue

        foreignKey.isDeferrable = draft.isDeferrable
        foreignKey.isInitiallyDeferred = draft.isInitiallyDeferred
    }

    struct Draft {
        struct ColumnMapping: Identifiable {
            let id = UUID()
            var localColumn: String
            var referencedColumn: String
        }

        var name: String
        var referencedSchema: String
        var referencedTable: String
        var mappings: [ColumnMapping]
        var onUpdate: String
        var onDelete: String
        var isDeferrable: Bool
        var isInitiallyDeferred: Bool
        let isEditingExisting: Bool

        init(
            model: TableStructureEditorViewModel.ForeignKeyModel,
            availableColumns: [String]
        ) {
            self.name = model.name
            self.referencedSchema = model.referencedSchema
            self.referencedTable = model.referencedTable
            self.onUpdate = model.onUpdate ?? ForeignKeyAction.noAction.rawValue
            self.onDelete = model.onDelete ?? ForeignKeyAction.noAction.rawValue
            self.isDeferrable = model.isDeferrable
            self.isInitiallyDeferred = model.isInitiallyDeferred
            self.isEditingExisting = model.original != nil

            // Build mappings from parallel arrays
            var mappings: [ColumnMapping] = []
            for i in 0..<model.columns.count {
                let refCol = i < model.referencedColumns.count ? model.referencedColumns[i] : ""
                mappings.append(ColumnMapping(localColumn: model.columns[i], referencedColumn: refCol))
            }
            self.mappings = mappings
        }

        var canSave: Bool {
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !referencedTable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !mappings.isEmpty &&
                mappings.allSatisfy { !$0.localColumn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
    }
}
