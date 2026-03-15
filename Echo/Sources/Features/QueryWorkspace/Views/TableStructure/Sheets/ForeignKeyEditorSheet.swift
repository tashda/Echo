import SwiftUI
import Foundation
#if os(macOS)
import AppKit
#endif

struct ForeignKeyEditorSheet: View {
    @Binding var foreignKey: TableStructureEditorViewModel.ForeignKeyModel
    let availableColumns: [String]
    let onDelete: () -> Void
    let onCancelNew: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State var draft: Draft

    init(
        foreignKey: Binding<TableStructureEditorViewModel.ForeignKeyModel>,
        availableColumns: [String],
        onDelete: @escaping () -> Void,
        onCancelNew: @escaping () -> Void
    ) {
        self._foreignKey = foreignKey
        self.availableColumns = availableColumns
        self.onDelete = onDelete
        self.onCancelNew = onCancelNew
        _draft = State(initialValue: Draft(model: foreignKey.wrappedValue, availableColumns: availableColumns))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Form {
                    generalSection
                    columnsSection
                    referenceSection
                    actionsSection
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            }

            Divider()

            toolbar
        }
        .frame(minWidth: 520, idealWidth: 560, minHeight: 500)
        .navigationTitle(draft.isEditingExisting ? "Edit Foreign Key" : "New Foreign Key")
    }

    private var generalSection: some View {
        Section {
            LabeledContent("Name") {
                TextField("Constraint name", text: $draft.name)
            }

            LabeledContent("Schema") {
                TextField("public", text: $draft.referencedSchema)
            }

            LabeledContent("Table") {
                TextField("Referenced table", text: $draft.referencedTable)
            }
        } header: {
            Text("General")
        } footer: {
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Name is required.")
                        .foregroundStyle(ColorTokens.Status.error)
                }
                if draft.referencedTable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Referenced table is required.")
                        .foregroundStyle(ColorTokens.Status.error)
                }
            }
        }
    }

    private var columnsSection: some View {
        Section {
            ForEach(Array(draft.columns.enumerated()), id: \.element.id) { index, column in
                columnRow(for: draftBinding(for: column.id), index: index)
            }

            HStack {
                Menu {
                    ForEach(computedAddableColumns, id: \.self) { name in
                        Button(name) {
                            addDraftColumn(named: name)
                        }
                    }
                } label: {
                    Label("Add Column", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .disabled(computedAddableColumns.isEmpty)

                Spacer()
            }
        } header: {
            Text("Columns")
        } footer: {
            if draft.columns.isEmpty {
                Text("At least one local column is required.")
                    .foregroundStyle(ColorTokens.Status.error)
            } else {
                Text("Order matches the referenced columns below.")
            }
        }
    }

    private func columnRow(for column: Binding<Draft.Column>, index: Int) -> some View {
        let columnID = column.wrappedValue.id
        return HStack(spacing: SpacingTokens.sm) {
            VStack(spacing: SpacingTokens.xxxs) {
                Button {
                    moveDraftColumn(at: index, by: -1)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(TypographyTokens.label)
                }
                .buttonStyle(.borderless)
                .disabled(index == 0)

                Button {
                    moveDraftColumn(at: index, by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(TypographyTokens.label)
                }
                .buttonStyle(.borderless)
                .disabled(index == draft.columns.count - 1)
            }
            .frame(width: SpacingTokens.md2)

            Picker("", selection: column.name) {
                ForEach(draftColumnOptions(for: columnID), id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)

            Button(role: .destructive) {
                removeDraftColumn(withID: columnID)
            } label: {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.borderless)
            .disabled(draft.columns.count <= 1)
        }
    }

    private var referenceSection: some View {
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

    private var actionsSection: some View {
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

    private var toolbar: some View {
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
