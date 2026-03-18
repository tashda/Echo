import SwiftUI

// MARK: - ForeignKeyEditorSheet Reference, Actions & Toolbar Sections

extension ForeignKeyEditorSheet {

    var referenceSection: some View {
        Section {
            PropertyRow(title: "Referenced Columns") {
                TextField("col1, col2", text: $draft.referencedColumnsInput)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        } header: {
            Text("References")
        } footer: {
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                Text("Comma-separated column names, matching the order above.")
                    .font(TypographyTokens.formDescription)
                if draft.referencedColumnsMismatch {
                    Text("Column count does not match local columns (\(draft.columns.count)).")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Status.warning)
                }
            }
        }
    }

    var actionsSection: some View {
        Section {
            PropertyRow(title: "ON UPDATE") {
                Picker("", selection: $draft.onUpdate) {
                    ForEach(ForeignKeyAction.allCases) { action in
                        Text(action.displayName).tag(action.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            PropertyRow(title: "ON DELETE") {
                Picker("", selection: $draft.onDelete) {
                    ForEach(ForeignKeyAction.allCases) { action in
                        Text(action.displayName).tag(action.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        } header: {
            Text("Actions")
        } footer: {
            Text("Determines behavior when the referenced row is updated or deleted.")
                .font(TypographyTokens.formDescription)
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
            .buttonStyle(.bordered)
            .keyboardShortcut(.cancelAction)

            Button("Save") {
                applyDraftToModel()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!draft.canSave)
            .keyboardShortcut(.defaultAction)
        }
        .padding(SpacingTokens.md)
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
