import SwiftUI

struct IndexEditorSheet: View {
    @Binding var index: TableStructureEditorViewModel.IndexModel
    let availableColumns: [String]
    let onDelete: () -> Void
    let onCancelNew: () -> Void

    @Environment(\.dismiss) internal var dismiss
    @State internal var draft: Draft
    @State private var showFilterInfo = false
    @State private var hoveredColumnID: UUID?

    init(
        index: Binding<TableStructureEditorViewModel.IndexModel>,
        availableColumns: [String],
        onDelete: @escaping () -> Void,
        onCancelNew: @escaping () -> Void
    ) {
        self._index = index
        self.availableColumns = availableColumns
        self.onDelete = onDelete
        self.onCancelNew = onCancelNew
        _draft = State(initialValue: Draft(model: index.wrappedValue, availableColumns: availableColumns))
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    LabeledContent("Name") {
                        TextField("", text: $draft.name)
                    }

                    Toggle("Unique", isOn: $draft.isUnique)

                    VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                        HStack {
                            Text("Filter")
                            Button {
                                showFilterInfo.toggle()
                            } label: {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(ColorTokens.Text.tertiary)
                            }
                            .buttonStyle(.borderless)
                            .popover(isPresented: $showFilterInfo, arrowEdge: .trailing) {
                                Text("Optional SQL WHERE condition for a partial index. Only rows matching this expression are included in the index.\n\nExample: status = 'active'")
                                    .font(TypographyTokens.detail)
                                    .multilineTextAlignment(.leading)
                                    .frame(width: 240, alignment: .leading)
                                    .padding(SpacingTokens.sm)
                            }
                        }

                        TextEditor(text: $draft.filterCondition)
                            .font(TypographyTokens.standard)
                            .frame(minHeight: 56, maxHeight: 56)
                            .padding(.vertical, SpacingTokens.xxs2)
                            .padding(.horizontal, SpacingTokens.xs)
                            .background(
                                RoundedRectangle(cornerRadius: SpacingTokens.xxs2)
                                    .fill(Color(nsColor: .textBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: SpacingTokens.xxs2)
                                    .stroke(Color(nsColor: .separatorColor))
                            )
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

            Divider()

            toolbar
        }
        .frame(minWidth: 420, idealWidth: 460, minHeight: 360)
        .navigationTitle(draft.isEditingExisting ? "Edit Index" : "New Index")
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

    private var toolbar: some View {
        HStack(spacing: SpacingTokens.sm) {
            if draft.isEditingExisting {
                Button("Delete Index", role: .destructive) {
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
