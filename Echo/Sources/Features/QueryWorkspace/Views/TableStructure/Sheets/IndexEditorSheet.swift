import SwiftUI

struct IndexEditorSheet: View {
    @Binding var index: TableStructureEditorViewModel.IndexModel
    let availableColumns: [String]
    let databaseType: DatabaseType
    let onDelete: () -> Void
    let onCancelNew: () -> Void

    @Environment(\.dismiss) internal var dismiss
    @State internal var draft: Draft
    @State private var showFilterInfo = false
    @State private var hoveredColumnID: UUID?

    init(
        index: Binding<TableStructureEditorViewModel.IndexModel>,
        availableColumns: [String],
        databaseType: DatabaseType,
        onDelete: @escaping () -> Void,
        onCancelNew: @escaping () -> Void
    ) {
        self._index = index
        self.availableColumns = availableColumns
        self.databaseType = databaseType
        self.onDelete = onDelete
        self.onCancelNew = onCancelNew
        _draft = State(initialValue: Draft(model: index.wrappedValue, availableColumns: availableColumns))
    }

    var body: some View {
        SheetLayout(
            title: draft.isEditingExisting ? "Edit Index" : "New Index",
            icon: "list.bullet.indent",
            subtitle: draft.isEditingExisting ? "Modify index columns and options." : "Define a new index on selected columns.",
            primaryAction: "Save",
            canSubmit: draft.canSave,
            onSubmit: {
                applyDraft()
                dismiss()
            },
            onCancel: {
                cancelEditing()
            },
            destructiveAction: draft.isEditingExisting ? "Delete Index" : nil,
            onDestructive: draft.isEditingExisting ? {
                dismiss()
                onDelete()
            } : nil
        ) {
            Form {
                Section {
                    PropertyRow(title: "Name") {
                        TextField("", text: $draft.name, prompt: Text("IX_table_column"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }

                    PropertyRow(
                        title: "Unique",
                        info: "A unique index ensures that no two rows have the same values in the indexed columns. Useful for enforcing business rules like unique email addresses."
                    ) {
                        Toggle("", isOn: $draft.isUnique)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    if databaseType == .postgresql {
                        PropertyRow(
                            title: "Index Type",
                            info: "B-tree: Default, good for equality and range queries.\nHash: Fast equality lookups only.\nGIN: Generalized inverted index for full-text search, arrays, JSONB.\nGiST: Generalized search tree for geometric, range, and full-text data.\nBRIN: Block range index, very compact for naturally ordered large tables."
                        ) {
                            Picker("", selection: $draft.indexType) {
                                Text("B-tree").tag("btree")
                                Text("Hash").tag("hash")
                                Text("GIN").tag("gin")
                                Text("GiST").tag("gist")
                                Text("BRIN").tag("brin")
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                    } else if databaseType == .mysql {
                        PropertyRow(
                            title: "Index Type",
                            info: "B-tree and Hash are standard MySQL secondary index types. Fulltext supports natural-language search. Spatial is used for geometry data."
                        ) {
                            Picker("", selection: $draft.indexType) {
                                Text("B-tree").tag("btree")
                                Text("Hash").tag("hash")
                                Text("Fulltext").tag("fulltext")
                                Text("Spatial").tag("spatial")
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                    }

                    if databaseType != .mysql {
                        PropertyRow(
                            title: "Filter",
                            info: "Optional SQL WHERE condition for a partial index. Only rows matching this expression are included in the index.\n\nExample: status = 'active'"
                        ) {
                            TextField("", text: $draft.filterCondition, prompt: Text("e.g. status = 'active'"), axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(2...4)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                Section("Columns") {
                    ForEach(Array(draft.columns.enumerated()), id: \.element.id) { idx, column in
                        indexColumnRow(for: draftColumnBinding(for: column.id), index: idx)
                    }
                    .onMove { from, to in
                        draft.columns.move(fromOffsets: from, toOffset: to)
                    }

                    Menu {
                        ForEach(addableColumns, id: \.self) { columnName in
                            Button(columnName) {
                                addColumn(named: columnName)
                            }
                        }
                    } label: {
                        Label("Add Column", systemImage: "plus")
                    }
                    .menuStyle(.borderlessButton)
                    .disabled(addableColumns.isEmpty)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 420, idealWidth: 460, minHeight: 360)
    }

    private func indexColumnRow(for column: Binding<Draft.Column>, index: Int) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "line.3.horizontal")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)

            Text(column.wrappedValue.name)
                .font(TypographyTokens.standard)
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker("", selection: column.sortOrder) {
                Text("ASC").tag(TableStructureEditorViewModel.IndexModel.Column.SortOrder.ascending)
                Text("DESC").tag(TableStructureEditorViewModel.IndexModel.Column.SortOrder.descending)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            .opacity(column.wrappedValue.isIncluded ? 0 : 1)
            .disabled(column.wrappedValue.isIncluded)

            Picker("", selection: column.isIncluded) {
                Text("Key").tag(false)
                Text("Include").tag(true)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .fixedSize()

            Button(role: .destructive) {
                removeColumn(withID: column.wrappedValue.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(hoveredColumnID == column.wrappedValue.id ? ColorTokens.Status.error : ColorTokens.Text.secondary)
            }
            .buttonStyle(.borderless)
            .help("Remove column")
            .disabled(draft.columns.count <= 1)
            .onHover { isHovered in
                hoveredColumnID = isHovered ? column.wrappedValue.id : nil
            }
        }
    }

}
