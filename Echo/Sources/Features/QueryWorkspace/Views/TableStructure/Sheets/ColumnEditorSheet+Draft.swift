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
        let defaultTrimmed = draft.defaultValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let expressionTrimmed = draft.generatedExpression.trimmingCharacters(in: .whitespacesAndNewlines)
        let collationTrimmed = draft.collation.trimmingCharacters(in: .whitespacesAndNewlines)
        let characterSetTrimmed = draft.characterSet.trimmingCharacters(in: .whitespacesAndNewlines)
        let commentTrimmed = draft.comment.trimmingCharacters(in: .whitespacesAndNewlines)
        let updatedColumn = TableStructureEditorViewModel.ColumnModel(
            original: column.original,
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            dataType: draft.dataType.trimmingCharacters(in: .whitespacesAndNewlines),
            isNullable: draft.isNullable,
            defaultValue: defaultTrimmed.isEmpty ? nil : defaultTrimmed,
            generatedExpression: expressionTrimmed.isEmpty ? nil : expressionTrimmed,
            isIdentity: draft.isIdentity,
            identitySeed: draft.isIdentity ? Int(draft.identitySeed) : nil,
            identityIncrement: draft.isIdentity ? Int(draft.identityIncrement) : nil,
            identityGeneration: draft.isIdentity ? draft.identityGeneration : nil,
            collation: collationTrimmed.isEmpty ? nil : collationTrimmed,
            characterSet: characterSetTrimmed.isEmpty ? nil : characterSetTrimmed,
            comment: commentTrimmed.isEmpty ? nil : commentTrimmed,
            isUnsigned: draft.isUnsigned,
            isZerofill: draft.isZerofill,
            ordinalPosition: column.ordinalPosition
        )

        if draft.isEditingExisting {
            column = updatedColumn
            dismiss()
        } else {
            dismiss()
            Task { @MainActor in
                onSaveNew?(updatedColumn)
            }
        }
    }

    func cancelEditing() {
        dismiss()
        if !draft.isEditingExisting {
            onCancelNew()
        }
    }
}
