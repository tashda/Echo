import SwiftUI

// MARK: - ForeignKeyEditorSheet Actions, Deferrable & Toolbar Sections

extension ForeignKeyEditorSheet {

    var actionsSection: some View {
        Section {
            PropertyRow(
                title: "ON UPDATE",
                info: "No Action: Raise error if referenced row is updated.\nCascade: Automatically update matching rows.\nSet Null: Set foreign key columns to NULL.\nSet Default: Set foreign key columns to their default values.\nRestrict: Prevent the update (checked immediately)."
            ) {
                Picker("", selection: $draft.onUpdate) {
                    ForEach(ForeignKeyAction.allCases) { action in
                        Text(action.displayName).tag(action.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            PropertyRow(
                title: "ON DELETE",
                info: "No Action: Raise error if referenced row is deleted.\nCascade: Automatically delete matching rows.\nSet Null: Set foreign key columns to NULL.\nSet Default: Set foreign key columns to their default values.\nRestrict: Prevent the deletion (checked immediately)."
            ) {
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

    var deferrableSection: some View {
        Section("Deferrable") {
            PropertyRow(
                title: "Deferrable",
                info: "A deferrable constraint can be checked at the end of a transaction instead of immediately. This allows temporary violations during multi-statement operations."
            ) {
                Toggle("", isOn: $draft.isDeferrable)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: draft.isDeferrable) { _, newValue in
                        if !newValue { draft.isInitiallyDeferred = false }
                    }
            }

            if draft.isDeferrable {
                PropertyRow(title: "Initially Deferred") {
                    Toggle("", isOn: $draft.isInitiallyDeferred)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }
        }
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
