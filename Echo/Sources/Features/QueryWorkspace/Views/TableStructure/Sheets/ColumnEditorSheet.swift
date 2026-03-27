import SwiftUI
import Foundation
#if os(macOS)
import AppKit
#endif

struct ColumnEditorSheet: View {
    @Binding var column: TableStructureEditorViewModel.ColumnModel
    let databaseType: DatabaseType
    let onDelete: () -> Void
    let onCancelNew: () -> Void

    @Environment(\.dismiss) internal var dismiss
    @State internal var draft: Draft

    init(
        column: Binding<TableStructureEditorViewModel.ColumnModel>,
        databaseType: DatabaseType,
        onDelete: @escaping () -> Void,
        onCancelNew: @escaping () -> Void
    ) {
        self._column = column
        self.databaseType = databaseType
        self.onDelete = onDelete
        self.onCancelNew = onCancelNew
        _draft = State(initialValue: Draft(model: column.wrappedValue, databaseType: databaseType))
    }

    var body: some View {
        SheetLayout(
            title: draft.isEditingExisting ? "Edit Column" : "New Column",
            icon: "tablecells",
            subtitle: draft.isEditingExisting ? "Modify column properties." : "Define a new column for this table.",
            primaryAction: "Save",
            canSubmit: draft.canSave,
            onSubmit: {
                applyDraft()
            },
            onCancel: {
                cancelEditing()
            },
            destructiveAction: draft.isEditingExisting ? "Delete Column" : nil,
            onDestructive: draft.isEditingExisting ? {
                dismiss()
                onDelete()
            } : nil
        ) {
            Form {
                generalSection
                behaviorSection
                identitySection
                collationSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 440, idealWidth: 500, minHeight: 440)
    }

    private var generalSection: some View {
        Section {
            PropertyRow(title: "Column Name") {
                TextField("", text: $draft.name, prompt: Text("column_name"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
            
            PropertyRow(title: "Data Type") {
                DataTypePicker(selection: dataTypeInputBinding, databaseType: databaseType)
            }
        } footer: {
            if !draft.canSave {
                Text("Name and data type cannot be empty.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Status.error)
            }
        }
    }

    @State private var showGeneratedExpressionInfo = false

    private var behaviorSection: some View {
        Section {
            PropertyRow(title: "Allow NULL values") {
                Toggle("", isOn: $draft.isNullable)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            PropertyRow(title: "Default Value") {
                TextField("", text: $draft.defaultValue, prompt: Text("e.g. 0, 'active', now()"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(
                title: "Generated Expression",
                info: "A SQL expression that automatically computes this column's value. Generated columns cannot be written to directly.\n\nExample: price * quantity"
            ) {
                TextField("", text: $draft.generatedExpression, prompt: Text("e.g. price * quantity"), axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(2...4)
                    .multilineTextAlignment(.trailing)
            }
        } header: {
            Text("Behavior")
        } footer: {
            Text("Leave optional fields blank to omit them.")
                .font(TypographyTokens.formDescription)
        }
    }

    var hasDataTypeDropdown: Bool {
        databaseType == .postgresql || databaseType == .microsoftSQL
    }

}
