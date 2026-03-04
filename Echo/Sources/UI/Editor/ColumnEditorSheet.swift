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

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var draft: Draft

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
            labeledRow(title: "Column Name") {
                TextField("", text: $draft.name)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            if isPostgres {
                labeledRow(title: "Data Type") {
                    Picker("", selection: postgresTypeSelectionBinding) {
                        Text("Custom").tag("")
                        ForEach(postgresDataTypeOptions, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 180, alignment: .trailing)
                }
                if draft.selectedDataType == nil {
                    labeledRow(title: "Custom Data Type") {
                        TextField("", text: dataTypeInputBinding)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            } else {
                labeledRow(title: "Data Type") {
                    TextField("", text: dataTypeInputBinding)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        } footer: {
            if !draft.canSave {
                Text("Name and data type cannot be empty.")
                    .foregroundStyle(.red)
            }
        }
    }

    private var behaviorSection: some View {
        Section {
            Toggle("Allow NULL values", isOn: $draft.isNullable)
            labeledRow(title: "Default Value") {
                TextField("", text: $draft.defaultValue)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Generated Expression")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $draft.generatedExpression)
                    .font(.system(size: 13))
                    .frame(minHeight: generatedExpressionHeight, maxHeight: generatedExpressionHeight)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(fieldBackgroundColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(fieldStrokeColor, lineWidth: 1)
                    )
            }
        } header: {
            Text("Behavior")
        } footer: {
            Text("Leave optional fields blank to omit them.")
        }
    }

    private func labeledRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .frame(minWidth: 120, alignment: .leading)
            Spacer(minLength: 0)
            content()
        }
        .frame(maxWidth: .infinity)
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            if draft.isEditingExisting {
                Button("Delete Column", role: .destructive) {
                    dismiss()
                    onDelete()
                }
                .buttonStyle(.bordered)
                .tint(.red)
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
            .tint(themeManager.accentColor)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(toolbarBackgroundColor)
        .overlay(
            Rectangle()
                .fill(toolbarBorderColor)
                .frame(height: 1),
            alignment: .top
        )
    }

    private func applyDraft() {
        column.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        column.dataType = draft.dataType.trimmingCharacters(in: .whitespacesAndNewlines)
        column.isNullable = draft.isNullable

        let defaultTrimmed = draft.defaultValue.trimmingCharacters(in: .whitespacesAndNewlines)
        column.defaultValue = defaultTrimmed.isEmpty ? nil : defaultTrimmed

        let expressionTrimmed = draft.generatedExpression.trimmingCharacters(in: .whitespacesAndNewlines)
        column.generatedExpression = expressionTrimmed.isEmpty ? nil : expressionTrimmed

        dismiss()
    }

    private func cancelEditing() {
        dismiss()
        if !draft.isEditingExisting {
            onCancelNew()
        }
    }

    private var isPostgres: Bool { databaseType == .postgresql }

    private var fieldBackgroundColor: Color {
        #if os(macOS)
        Color(nsColor: themeManager.surfaceBackgroundNSColor).opacity(0.9)
        #else
        themeManager.surfaceBackgroundColor.opacity(0.9)
        #endif
    }

    private var fieldStrokeColor: Color {
        let foreground = themeManager.surfaceForegroundColor
        return foreground.opacity(themeManager.effectiveColorScheme == .dark ? 0.18 : 0.25)
    }

    private var toolbarBackgroundColor: Color {
#if os(macOS)
        Color(nsColor: themeManager.surfaceBackgroundNSColor)
#else
        themeManager.surfaceBackgroundColor
#endif
    }

    private var toolbarBorderColor: Color {
        themeManager.surfaceForegroundColor.opacity(themeManager.effectiveColorScheme == .dark ? 0.3 : 0.12)
    }

    private var generatedExpressionHeight: CGFloat {
        CGFloat(88) // approximate four lines of text
    }

    private var postgresTypeSelectionBinding: Binding<String> {
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

    private var dataTypeInputBinding: Binding<String> {
        Binding(
            get: { draft.dataType },
            set: { newValue in
                draft.dataType = newValue
                updateSelectedPreset(for: newValue)
            }
        )
    }

    private func updateSelectedPreset(for value: String) {
        guard isPostgres else { return }
        if let match = postgresDataTypeOptions.first(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
            draft.selectedDataType = match
        } else {
            draft.selectedDataType = nil
        }
    }

    private struct Draft {
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
}
