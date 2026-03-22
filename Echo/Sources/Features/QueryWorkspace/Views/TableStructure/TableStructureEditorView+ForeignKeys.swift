import SwiftUI

extension TableStructureEditorView {

    internal var relationsContent: some View {
        Group {
            if activeForeignKeys.isEmpty && viewModel.dependencies.isEmpty {
                ContentUnavailableView {
                    Label("No Relations", systemImage: "link")
                } description: {
                    Text("Foreign keys define referential relationships between tables.")
                } actions: {
                    Button("Add Foreign Key") { presentNewForeignKey() }
                }
            } else {
                VStack(spacing: 0) {
                    if !activeForeignKeys.isEmpty {
                        foreignKeysTable
                    }

                    if !viewModel.dependencies.isEmpty {
                        if !activeForeignKeys.isEmpty {
                            Divider()
                        }
                        dependenciesSection
                    }
                }
            }
        }
    }

    internal var activeForeignKeys: [TableStructureEditorViewModel.ForeignKeyModel] {
        viewModel.foreignKeys.filter { !$0.isDeleted }
    }

    private var foreignKeysTable: some View {
        Table(of: TableStructureEditorViewModel.ForeignKeyModel.self, selection: $selectedForeignKeyIDs) {
            TableColumn("Kind") { _ in
                Text("FK")
                    .font(TypographyTokens.Table.kindBadge)
                    .foregroundStyle(.green)
            }
            .width(35)

            TableColumn("Name") { fk in
                Text(fk.name)
                    .font(TypographyTokens.Table.name)
                    .help(fk.name)
            }
            .width(min: 120, ideal: 180)

            TableColumn("Columns") { fk in
                Text(fk.columns.joined(separator: ", "))
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
                    .help(fk.columns.joined(separator: ", "))
            }
            .width(min: 80, ideal: 120)

            TableColumn("Referenced Table") { fk in
                Text("\(fk.referencedSchema).\(fk.referencedTable)")
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
                    .help("\(fk.referencedSchema).\(fk.referencedTable)")
            }
            .width(min: 80, ideal: 140)

            TableColumn("Referenced Columns") { fk in
                Text(fk.referencedColumns.joined(separator: ", "))
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
                    .help(fk.referencedColumns.joined(separator: ", "))
            }
            .width(min: 80, ideal: 120)

            TableColumn("Actions") { fk in
                HStack(spacing: SpacingTokens.sm) {
                    if let onUpdate = fk.onUpdate, !onUpdate.isEmpty {
                        Text("UPD: \(onUpdate)")
                            .font(TypographyTokens.Table.category)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    if let onDelete = fk.onDelete, !onDelete.isEmpty {
                        Text("DEL: \(onDelete)")
                            .font(TypographyTokens.Table.category)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    if fk.onUpdate == nil && fk.onDelete == nil {
                        Text("\u{2014}")
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                }
            }
            .width(min: 80, ideal: 140)
        } rows: {
            ForEach(activeForeignKeys) { fk in
                TableRow(fk)
            }
        }
        .contextMenu(forSelectionType: TableStructureEditorViewModel.ForeignKeyModel.ID.self) { selection in
            foreignKeyContextMenu(for: selection)
        } primaryAction: { selection in
            if let fkID = selection.first,
               let fk = activeForeignKeys.first(where: { $0.id == fkID }) {
                presentForeignKeyEditor(for: fk)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .environment(\.defaultMinListRowHeight, 28)
    }

    @ViewBuilder
    private func foreignKeyContextMenu(for selection: Set<TableStructureEditorViewModel.ForeignKeyModel.ID>) -> some View {
        if selection.isEmpty {
            Button("Add Foreign Key") { presentNewForeignKey() }
        } else if let fkID = selection.first,
           let fk = activeForeignKeys.first(where: { $0.id == fkID }) {
            Button("Edit Foreign Key") {
                presentForeignKeyEditor(for: fk)
            }
            Divider()
            Button("Delete Foreign Key", role: .destructive) {
                viewModel.removeForeignKey(fk)
            }
        }
    }

    // MARK: - Dependencies (Read-Only)

    private var dependenciesSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: SpacingTokens.xs) {
                Text("Dependencies")
                    .font(TypographyTokens.standard.weight(.medium))
                    .foregroundStyle(ColorTokens.Text.primary)

                Text("\(viewModel.dependencies.count)")
                    .font(TypographyTokens.label.weight(.medium))
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .padding(.horizontal, SpacingTokens.xxs2)
                    .padding(.vertical, SpacingTokens.xxxs)
                    .background(ColorTokens.Text.primary.opacity(0.06), in: Capsule())

                Spacer()
            }
            .padding(.horizontal, SpacingTokens.lg)
            .padding(.vertical, SpacingTokens.xs)

            Divider()

            dependenciesTable
        }
    }

    private var dependenciesTable: some View {
        Table(viewModel.dependencies) {
            TableColumn("Kind") { _ in
                Text("DEP")
                    .font(TypographyTokens.Table.kindBadge)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
            .width(35)

            TableColumn("Name") { dep in
                Text(dep.name)
                    .font(TypographyTokens.Table.name)
                    .help(dep.name)
            }
            .width(min: 120, ideal: 180)

            TableColumn("Columns") { dep in
                Text(dep.baseColumns.joined(separator: ", "))
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
            }
            .width(min: 80, ideal: 120)

            TableColumn("Referenced Table") { dep in
                Text("\(dep.referencedTable)(\(dep.referencedColumns.joined(separator: ", ")))")
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
            }
            .width(min: 120, ideal: 240)

            TableColumn("Actions") { dep in
                HStack(spacing: SpacingTokens.sm) {
                    if let onUpdate = dep.onUpdate, !onUpdate.isEmpty {
                        Text("UPD: \(onUpdate)")
                            .font(TypographyTokens.Table.category)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    if let onDelete = dep.onDelete, !onDelete.isEmpty {
                        Text("DEL: \(onDelete)")
                            .font(TypographyTokens.Table.category)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    if dep.onUpdate == nil && dep.onDelete == nil {
                        Text("\u{2014}")
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                }
            }
            .width(min: 80, ideal: 140)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .environment(\.defaultMinListRowHeight, 28)
    }

    internal func presentNewForeignKey() {
        let model = viewModel.addForeignKey()
        activeForeignKeyEditor = ForeignKeyEditorPresentation(foreignKeyID: model.id, isNew: true)
    }

    private func presentForeignKeyEditor(for foreignKey: TableStructureEditorViewModel.ForeignKeyModel) {
        activeForeignKeyEditor = ForeignKeyEditorPresentation(foreignKeyID: foreignKey.id, isNew: foreignKey.isNew)
    }
}
