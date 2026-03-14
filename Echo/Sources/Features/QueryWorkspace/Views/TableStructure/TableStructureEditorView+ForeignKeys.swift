import SwiftUI

extension TableStructureEditorView {

    internal var relationsContent: some View {
        VStack(spacing: 0) {
            sectionToolbar(title: "Foreign Keys", count: activeForeignKeys.count) {
                presentNewForeignKey()
            }

            Divider()

            if activeForeignKeys.isEmpty && viewModel.dependencies.isEmpty {
                EmptyStatePlaceholder(
                    icon: "link",
                    title: "No Relations",
                    subtitle: "Foreign keys define referential relationships between tables.",
                    actionTitle: "Add Foreign Key"
                ) {
                    presentNewForeignKey()
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
            TableColumn("Name") { fk in
                HStack(spacing: SpacingTokens.xxs) {
                    if fk.isNew || fk.isDirty {
                        Circle()
                            .fill(accentColor)
                            .frame(width: SpacingTokens.xxs2, height: SpacingTokens.xxs2)
                    }
                    Text(fk.name)
                        .font(TypographyTokens.standard.weight(.medium))
                        .help(fk.name)
                }
            }
            .width(min: 120, ideal: 200)

            TableColumn("Columns") { fk in
                Text(fk.columns.joined(separator: ", "))
                    .font(TypographyTokens.detail.monospaced())
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
                    .help(fk.columns.joined(separator: ", "))
            }
            .width(min: 80, ideal: 140)

            TableColumn("References") { fk in
                Text("\(fk.referencedSchema).\(fk.referencedTable)(\(fk.referencedColumns.joined(separator: ", ")))")
                    .font(TypographyTokens.detail.monospaced())
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
                    .help("\(fk.referencedSchema).\(fk.referencedTable)(\(fk.referencedColumns.joined(separator: ", ")))")
            }
            .width(min: 120, ideal: 260)

            TableColumn("Actions") { fk in
                HStack(spacing: SpacingTokens.sm) {
                    if let onUpdate = fk.onUpdate, !onUpdate.isEmpty {
                        Text("UPD: \(onUpdate)")
                            .font(TypographyTokens.label.monospaced())
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    if let onDelete = fk.onDelete, !onDelete.isEmpty {
                        Text("DEL: \(onDelete)")
                            .font(TypographyTokens.label.monospaced())
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    if fk.onUpdate == nil && fk.onDelete == nil {
                        Text("\u{2014}")
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                }
            }
            .width(min: 80, ideal: 160)
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
        .tableStyle(.bordered(alternatesRowBackgrounds: true))
        .environment(\.defaultMinListRowHeight, 28)
    }

    @ViewBuilder
    private func foreignKeyContextMenu(for selection: Set<TableStructureEditorViewModel.ForeignKeyModel.ID>) -> some View {
        if let fkID = selection.first,
           let fk = activeForeignKeys.first(where: { $0.id == fkID }) {
            Button("Edit Foreign Key\u{2026}") {
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
            TableColumn("Name") { dep in
                Text(dep.name)
                    .font(TypographyTokens.standard.weight(.medium))
                    .help(dep.name)
            }
            .width(min: 120, ideal: 200)

            TableColumn("Columns") { dep in
                Text(dep.baseColumns.joined(separator: ", "))
                    .font(TypographyTokens.detail.monospaced())
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
            }
            .width(min: 80, ideal: 140)

            TableColumn("Referenced Table") { dep in
                Text("\(dep.referencedTable)(\(dep.referencedColumns.joined(separator: ", ")))")
                    .font(TypographyTokens.detail.monospaced())
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
            }
            .width(min: 120, ideal: 260)

            TableColumn("Actions") { dep in
                HStack(spacing: SpacingTokens.sm) {
                    if let onUpdate = dep.onUpdate, !onUpdate.isEmpty {
                        Text("UPD: \(onUpdate)")
                            .font(TypographyTokens.label.monospaced())
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    if let onDelete = dep.onDelete, !onDelete.isEmpty {
                        Text("DEL: \(onDelete)")
                            .font(TypographyTokens.label.monospaced())
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    if dep.onUpdate == nil && dep.onDelete == nil {
                        Text("\u{2014}")
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                }
            }
            .width(min: 80, ideal: 160)
        }
        .tableStyle(.bordered(alternatesRowBackgrounds: true))
        .environment(\.defaultMinListRowHeight, 28)
    }

    private func presentNewForeignKey() {
        let model = viewModel.addForeignKey()
        activeForeignKeyEditor = ForeignKeyEditorPresentation(foreignKeyID: model.id, isNew: true)
    }

    private func presentForeignKeyEditor(for foreignKey: TableStructureEditorViewModel.ForeignKeyModel) {
        activeForeignKeyEditor = ForeignKeyEditorPresentation(foreignKeyID: foreignKey.id, isNew: foreignKey.isNew)
    }
}
