import SwiftUI
import Foundation
#if os(macOS)
import AppKit
#endif

struct UniqueConstraintEditorSheet: View {
    @Binding var constraint: TableStructureEditorViewModel.UniqueConstraintModel
    let availableColumns: [String]
    let onDelete: () -> Void
    let onCancelNew: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State var draft: Draft

    init(
        constraint: Binding<TableStructureEditorViewModel.UniqueConstraintModel>,
        availableColumns: [String],
        onDelete: @escaping () -> Void,
        onCancelNew: @escaping () -> Void
    ) {
        self._constraint = constraint
        self.availableColumns = availableColumns
        self.onDelete = onDelete
        self.onCancelNew = onCancelNew
        _draft = State(initialValue: Draft(model: constraint.wrappedValue, availableColumns: availableColumns))
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                generalSection
                columnsSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            toolbar
        }
        .frame(minWidth: 460, idealWidth: 500, minHeight: 400)
        .navigationTitle(draft.isEditingExisting ? "Edit Unique Constraint" : "New Unique Constraint")
    }

    private var generalSection: some View {
        Section {
            TextField("Constraint Name", text: $draft.name)
        } header: {
            Text("General")
        } footer: {
            if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Name is required.")
                    .foregroundStyle(.red)
            }
        }
    }

    private var columnsSection: some View {
        Section {
            ForEach(Array(draft.columns.enumerated()), id: \.element.id) { index, column in
                columnRow(for: bindingForColumn(column.id), index: index)
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
                Text("At least one column is required.")
                    .foregroundStyle(.red)
            } else if computedAddableColumns.isEmpty {
                Text("All available columns are already included.")
            } else {
                Text("Order of columns can be important for some databases.")
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
                ForEach(columnOptionsForColumn(columnID), id: \.self) { option in
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
                Button("Delete Constraint", role: .destructive) {
                    dismiss()
                    onDelete()
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            Button("Cancel") {
                dismiss()
                cancelIfNew()
            }
            .keyboardShortcut(.cancelAction)

            Button("Save") {
                applyDraftChanges()
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

    struct Draft {
        struct Column: Identifiable {
            let id = UUID()
            var name: String
        }

        var name: String
        var columns: [Column]
        let isEditingExisting: Bool

        init(model: TableStructureEditorViewModel.UniqueConstraintModel, availableColumns: [String]) {
            self.name = model.name
            self.columns = model.columns.map { .init(name: $0) }
            self.isEditingExisting = !model.isNew

            if columns.isEmpty, let first = availableColumns.first {
                self.columns = [.init(name: first)]
            }
        }

        var canSave: Bool {
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !columns.isEmpty &&
                columns.allSatisfy { !$0.name.isEmpty }
        }
    }
}
