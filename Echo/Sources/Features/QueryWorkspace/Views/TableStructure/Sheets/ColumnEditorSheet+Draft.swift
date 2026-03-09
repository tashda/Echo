import SwiftUI
import Foundation

extension ColumnEditorSheet {
    struct Draft {
        var name: String
        var dataType: String
        var isNullable: Bool
        var defaultValue: String
        var generatedExpression: String
        let isEditingExisting: Bool
        var selectedDataType: String?

        init(model: TableStructureEditorViewModel.ColumnModel, databaseType: DatabaseType) {
            self.name = model.name
            self.dataType = model.dataType
            self.isNullable = model.isNullable
            self.defaultValue = model.defaultValue ?? ""
            self.generatedExpression = model.generatedExpression ?? ""
            self.isEditingExisting = !model.isNew
            if databaseType == .postgresql,
               let match = postgresDataTypeOptions.first(where: { $0.caseInsensitiveCompare(model.dataType) == .orderedSame }) {
                self.selectedDataType = match
            } else {
                self.selectedDataType = nil
            }
        }

        var canSave: Bool {
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !dataType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var postgresTypeSelectionBinding: Binding<String> {
        Binding<String>(
            get: { draft.selectedDataType ?? "" },
            set: { newValue in
                draft.selectedDataType = newValue.isEmpty ? nil : newValue
                if !newValue.isEmpty {
                    draft.dataType = newValue
                }
            }
        )
    }

    var dataTypeInputBinding: Binding<String> {
        Binding(
            get: { draft.dataType },
            set: { newValue in
                draft.dataType = newValue
                updateSelectedPreset(for: newValue)
            }
        )
    }

    func updateSelectedPreset(for value: String) {
        guard isPostgres else { return }
        if let match = postgresDataTypeOptions.first(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
            draft.selectedDataType = match
        } else {
            draft.selectedDataType = nil
        }
    }

    func applyDraft() {
        column.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        column.dataType = draft.dataType.trimmingCharacters(in: .whitespacesAndNewlines)
        column.isNullable = draft.isNullable

        let defaultTrimmed = draft.defaultValue.trimmingCharacters(in: .whitespacesAndNewlines)
        column.defaultValue = defaultTrimmed.isEmpty ? nil : defaultTrimmed

        let expressionTrimmed = draft.generatedExpression.trimmingCharacters(in: .whitespacesAndNewlines)
        column.generatedExpression = expressionTrimmed.isEmpty ? nil : expressionTrimmed

        dismiss()
    }

    func cancelEditing() {
        dismiss()
        if !draft.isEditingExisting {
            onCancelNew()
        }
    }
}
