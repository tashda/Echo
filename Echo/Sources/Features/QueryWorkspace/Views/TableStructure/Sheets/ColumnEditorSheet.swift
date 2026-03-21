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
        VStack(spacing: 0) {
            Form {
                generalSection
                behaviorSection
                identitySection
                collationSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            toolbar
        }
        .frame(minWidth: 440, idealWidth: 500, minHeight: 440)
        .navigationTitle(draft.isEditingExisting ? "Edit Column" : "New Column")
    }

    private var generalSection: some View {
        Section {
            PropertyRow(title: "Column Name") {
                TextField("", text: $draft.name, prompt: Text("column_name"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
            
            if hasDataTypeDropdown {
                PropertyRow(title: "Data Type") {
                    Picker("", selection: typeSelectionBinding) {
                        Text("Custom").tag("")
                        ForEach(dataTypeOptions(for: databaseType), id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
                
                if draft.selectedDataType == nil {
                    PropertyRow(title: "Custom Data Type") {
                        TextField("", text: dataTypeInputBinding, prompt: Text("e.g. int, varchar(255)"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }
            } else {
                PropertyRow(title: "Data Type") {
                    TextField("", text: dataTypeInputBinding, prompt: Text("e.g. int, varchar(255)"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
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

    private var toolbar: some View {
        HStack(spacing: SpacingTokens.sm) {
            if draft.isEditingExisting {
                Button("Delete Column", role: .destructive) {
                    dismiss()
                    onDelete()
                }
                .buttonStyle(.bordered)
                .tint(ColorTokens.Status.error)
            }

            Spacer()

            Button("Cancel") {
                cancelEditing()
            }
            .keyboardShortcut(.cancelAction)

            Button("Save") {
                applyDraft()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!draft.canSave)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, SpacingTokens.md2)
        .padding(.vertical, SpacingTokens.sm2)
        .background(.bar)
    }

    var hasDataTypeDropdown: Bool {
        databaseType == .postgresql || databaseType == .microsoftSQL
    }

}
