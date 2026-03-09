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
            Form {
                generalSection
                columnsSection
                referenceSection
                actionsSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            toolbar
        }
        .frame(minWidth: 520, idealWidth: 560, minHeight: 460)
        .navigationTitle(draft.isEditingExisting ? "Edit Foreign Key" : "New Foreign Key")
    }

    private var generalSection: some View {
        Section {
            TextField("Constraint Name", text: $draft.name)

            HStack {
                TextField("Schema", text: $draft.referencedSchema)
                TextField("Table", text: $draft.referencedTable)
            }
        } header: {
            Text("General")
        } footer: {
            VStack(alignment: .leading, spacing: 2) {
                if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Name is required.")
                        .foregroundStyle(.red)
                }
                if draft.referencedTable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Referenced table is required.")
                        .foregroundStyle(.red)
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
                    .foregroundStyle(.red)
            } else if computedAddableColumns.isEmpty {
                Text("All columns are already included.")
            } else {
                Text("Order matches the referenced columns below.")
            }
        }
    }

    private func columnRow(for column: Binding<Draft.Column>, index: Int) -> some View {
        let columnID = column.wrappedValue.id
        return HStack(spacing: 12) {
            VStack(spacing: 2) {
                Button {
                    moveDraftColumn(at: index, by: -1)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(TypographyTokens.label.weight(.bold))
                }
                .buttonStyle(.borderless)
                .disabled(index == 0)

                Button {
                    moveDraftColumn(at: index, by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(TypographyTokens.label.weight(.bold))
                }
                .buttonStyle(.borderless)
                .disabled(index == draft.columns.count - 1)
            }
            .frame(width: 24)

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

    private var toolbar: some View {
        HStack(spacing: 12) {
            if draft.isEditingExisting {
                Button("Delete Foreign Key", role: .destructive) {
                    dismiss()
                    onDelete()
                }
                .buttonStyle(.bordered)
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
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
