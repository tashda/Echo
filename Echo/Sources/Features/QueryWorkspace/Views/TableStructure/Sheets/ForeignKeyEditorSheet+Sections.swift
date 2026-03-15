import SwiftUI

// MARK: - ForeignKeyEditorSheet Reference, Actions & Toolbar Sections

extension ForeignKeyEditorSheet {

    var referenceSection: some View {
        Section {
            LabeledContent("Referenced Columns") {
                TextField("col1, col2", text: $draft.referencedColumnsInput)
            }
        } header: {
            Text("References")
        } footer: {
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                Text("Comma-separated column names, matching the order above.")
                if draft.referencedColumnsMismatch {
                    Text("Column count does not match local columns (\(draft.columns.count)).")
                        .foregroundStyle(ColorTokens.Status.warning)
                }
            }
        }
    }

    var actionsSection: some View {
        Section {
            Picker("ON UPDATE", selection: $draft.onUpdate) {
                ForEach(ForeignKeyAction.allCases) { action in
                    Text(action.displayName).tag(action.rawValue)
                }
            }

            Picker("ON DELETE", selection: $draft.onDelete) {
                ForEach(ForeignKeyAction.allCases) { action in
                    Text(action.displayName).tag(action.rawValue)
                }
            }
        } header: {
            Text("Actions")
        } footer: {
            Text("Determines behavior when the referenced row is updated or deleted.")
        }
    }

    var toolbar: some View {
        HStack(spacing: SpacingTokens.sm) {
            if draft.isEditingExisting {
                Button("Delete Foreign Key", role: .destructive) {
                    dismiss()
                    onDelete()
                }
                .buttonStyle(.bordered)
                .tint(ColorTokens.Status.error)
            }

            Spacer()

            Button("Cancel") {
                dismiss()
                if !draft.isEditingExisting {
                    onCancelNew()
                }
            }
            .keyboardShortcut(.cancelAction)

            Button("Save") {
                applyDraftToModel()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!draft.canSave)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, SpacingTokens.md2)
        .padding(.vertical, SpacingTokens.sm2)
        .background(.bar)
    }
}

// MARK: - ForeignKeyAction Enum

enum ForeignKeyAction: String, CaseIterable, Identifiable {
    case noAction = "NO ACTION"
    case cascade = "CASCADE"
    case setNull = "SET NULL"
    case setDefault = "SET DEFAULT"
    case restrict = "RESTRICT"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .noAction: return "No Action"
        case .cascade: return "Cascade"
        case .setNull: return "Set Null"
        case .setDefault: return "Set Default"
        case .restrict: return "Restrict"
        }
    }
}
