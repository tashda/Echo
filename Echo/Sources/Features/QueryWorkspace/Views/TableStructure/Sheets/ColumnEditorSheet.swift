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
    @EnvironmentObject internal var appearanceStore: AppearanceStore
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
                    .font(TypographyTokens.standard)
                    .frame(minHeight: generatedExpressionHeight, maxHeight: generatedExpressionHeight)
                    .padding(.vertical, SpacingTokens.xxs2)
                    .padding(.horizontal, SpacingTokens.xs)
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
            .tint(appearanceStore.accentColor)
        }
        .padding(.horizontal, SpacingTokens.md2)
        .padding(.vertical, SpacingTokens.sm2)
        .background(toolbarBackgroundColor)
        .overlay(
            Rectangle()
                .fill(toolbarBorderColor)
                .frame(height: 1),
            alignment: .top
        )
    }

    var isPostgres: Bool { databaseType == .postgresql }

    private var fieldBackgroundColor: Color {
        ColorTokens.Background.secondary.opacity(0.9)
    }

    private var fieldStrokeColor: Color {
        ColorTokens.Text.primary.opacity(appearanceStore.effectiveColorScheme == .dark ? 0.18 : 0.25)
    }

    private var toolbarBackgroundColor: Color {
        ColorTokens.Background.secondary
    }

    private var toolbarBorderColor: Color {
        ColorTokens.Text.primary.opacity(appearanceStore.effectiveColorScheme == .dark ? 0.3 : 0.12)
    }

    private var generatedExpressionHeight: CGFloat {
        CGFloat(88) // approximate four lines of text
    }

}
