import SwiftUI
import Foundation

extension ColumnEditorSheet {
    struct Draft {
        var name: String
        var dataType: String
        var isNullable: Bool
        var defaultValue: String
        var generatedExpression: String
        var isIdentity: Bool
        var identitySeed: String
        var identityIncrement: String
        var identityGeneration: String
        var collation: String
        var characterSet: String
        var comment: String
        var isUnsigned: Bool
        var isZerofill: Bool
        let isEditingExisting: Bool
        var selectedDataType: String?

        init(model: TableStructureEditorViewModel.ColumnModel, databaseType: DatabaseType) {
            self.name = model.name
            self.dataType = model.dataType
            self.isNullable = model.isNullable
            self.defaultValue = model.defaultValue ?? ""
            self.generatedExpression = model.generatedExpression ?? ""
            self.isIdentity = model.isIdentity
            self.identitySeed = model.identitySeed.map(String.init) ?? "1"
            self.identityIncrement = model.identityIncrement.map(String.init) ?? "1"
            self.identityGeneration = model.identityGeneration ?? "ALWAYS"
            self.collation = model.collation ?? ""
            self.characterSet = model.characterSet ?? ""
            self.comment = model.comment ?? ""
            self.isUnsigned = model.isUnsigned
            self.isZerofill = model.isZerofill
            self.isEditingExisting = !model.isNew
            let options = dataTypeOptions(for: databaseType)
            if !options.isEmpty,
               let match = options.first(where: { $0.caseInsensitiveCompare(model.dataType) == .orderedSame }) {
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

    var typeSelectionBinding: Binding<String> {
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
        let options = dataTypeOptions(for: databaseType)
        guard !options.isEmpty else { return }
        if let match = options.first(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
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

        column.isIdentity = draft.isIdentity
        column.identitySeed = draft.isIdentity ? Int(draft.identitySeed) : nil
        column.identityIncrement = draft.isIdentity ? Int(draft.identityIncrement) : nil
        column.identityGeneration = draft.isIdentity ? draft.identityGeneration : nil

        let collationTrimmed = draft.collation.trimmingCharacters(in: .whitespacesAndNewlines)
        column.collation = collationTrimmed.isEmpty ? nil : collationTrimmed
        let characterSetTrimmed = draft.characterSet.trimmingCharacters(in: .whitespacesAndNewlines)
        column.characterSet = characterSetTrimmed.isEmpty ? nil : characterSetTrimmed
        let commentTrimmed = draft.comment.trimmingCharacters(in: .whitespacesAndNewlines)
        column.comment = commentTrimmed.isEmpty ? nil : commentTrimmed
        column.isUnsigned = draft.isUnsigned
        column.isZerofill = draft.isZerofill

        dismiss()
    }

    func cancelEditing() {
        dismiss()
        if !draft.isEditingExisting {
            onCancelNew()
        }
    }
}
