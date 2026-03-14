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
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            toolbar
        }
        .frame(minWidth: 440, idealWidth: 500, minHeight: 360)
        .navigationTitle(draft.isEditingExisting ? "Edit Column" : "New Column")
    }

    private var generalSection: some View {
        Section {
            LabeledContent("Column Name") {
                TextField("", text: $draft.name)
            }
            if hasDataTypeDropdown {
                LabeledContent("Data Type") {
                    Picker("", selection: typeSelectionBinding) {
                        Text("Custom").tag("")
                        ForEach(dataTypeOptions(for: databaseType), id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                if draft.selectedDataType == nil {
                    LabeledContent("Custom Data Type") {
                        TextField("", text: dataTypeInputBinding)
                    }
                }
            } else {
                LabeledContent("Data Type") {
                    TextField("", text: dataTypeInputBinding)
                }
            }
        } footer: {
            if !draft.canSave {
                Text("Name and data type cannot be empty.")
                    .foregroundStyle(ColorTokens.Status.error)
            }
        }
    }

    @State private var showGeneratedExpressionInfo = false

    private var behaviorSection: some View {
        Section {
            Toggle("Allow NULL values", isOn: $draft.isNullable)

            LabeledContent("Default Value") {
                TextField("", text: $draft.defaultValue, prompt: Text("e.g. 0, 'active', now()"))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            LabeledContent {
                TextField("", text: $draft.generatedExpression, prompt: Text("e.g. price * quantity"), axis: .vertical)
                    .lineLimit(2...4)
            } label: {
                HStack(spacing: SpacingTokens.xxs) {
                    Text("Generated Expression")
                    Button {
                        showGeneratedExpressionInfo.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    .buttonStyle(.borderless)
                    .popover(isPresented: $showGeneratedExpressionInfo, arrowEdge: .trailing) {
                        Text("A SQL expression that automatically computes this column's value. Generated columns cannot be written to directly.\n\nExample: price * quantity")
                            .font(TypographyTokens.detail)
                            .multilineTextAlignment(.leading)
                            .frame(width: 240, alignment: .leading)
                            .padding(SpacingTokens.sm)
                    }
                }
            }
        } header: {
            Text("Behavior")
        } footer: {
            Text("Leave optional fields blank to omit them.")
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
