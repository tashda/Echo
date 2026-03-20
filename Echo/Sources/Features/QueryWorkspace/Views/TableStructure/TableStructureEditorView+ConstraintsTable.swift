import SwiftUI

/// A unified row model for displaying all constraint types in a single table.
struct ConstraintRowModel: Identifiable, Hashable {
    enum Kind: String, Hashable {
        case primaryKey = "PK"
        case unique = "UQ"
        case check = "CK"
    }

    let id: UUID
    let kind: Kind
    let name: String
    let definition: String
    let isDeferrable: Bool
    let isNew: Bool
    let isDirty: Bool
}

extension TableStructureEditorView {

    internal var constraintsContent: some View {
        Group {
            if constraintRows.isEmpty {
                ContentUnavailableView {
                    Label("No Constraints", systemImage: "shield.lefthalf.filled")
                } description: {
                    Text("Constraints enforce rules on data stored in this table.")
                } actions: {
                    Button("Add Constraint") { presentNewCheckConstraint() }
                }
            } else {
                constraintsTable
            }
        }
    }

    internal var constraintRows: [ConstraintRowModel] {
        var rows: [ConstraintRowModel] = []

        if let pk = viewModel.primaryKey {
            rows.append(ConstraintRowModel(
                id: pk.id,
                kind: .primaryKey,
                name: pk.name,
                definition: pk.columns.joined(separator: ", "),
                isDeferrable: pk.isDeferrable,
                isNew: pk.isNew,
                isDirty: pk.isDirty
            ))
        }

        for uq in viewModel.uniqueConstraints where !uq.isDeleted {
            rows.append(ConstraintRowModel(
                id: uq.id,
                kind: .unique,
                name: uq.name,
                definition: uq.columns.joined(separator: ", "),
                isDeferrable: uq.isDeferrable,
                isNew: uq.isNew,
                isDirty: uq.isDirty
            ))
        }

        for ck in viewModel.checkConstraints where !ck.isDeleted {
            rows.append(ConstraintRowModel(
                id: ck.id,
                kind: .check,
                name: ck.name,
                definition: ck.expression,
                isDeferrable: false,
                isNew: ck.isNew,
                isDirty: ck.isDirty
            ))
        }

        return rows
    }

    private var constraintsTable: some View {
        Table(of: ConstraintRowModel.self, selection: $selectedConstraintIDs) {
            TableColumn("Kind") { row in
                Text(row.kind.rawValue)
                    .font(TypographyTokens.Table.kindBadge)
                    .foregroundStyle(row.kind == .primaryKey ? .orange : row.kind == .unique ? .blue : ColorTokens.Text.tertiary)
            }
            .width(35)

            TableColumn("Name") { row in
                Text(row.name)
                    .font(TypographyTokens.Table.name)
                    .help(row.name)
            }
            .width(min: 120, ideal: 200)

            TableColumn("Definition") { row in
                Text(row.definition)
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
                    .help(row.definition)
            }
            .width(min: 120, ideal: 300)

            if viewModel.databaseType == .postgresql {
                TableColumn("Deferrable") { row in
                    if row.kind != .check {
                        Image(systemName: row.isDeferrable ? "checkmark" : "minus")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(row.isDeferrable ? accentColor : ColorTokens.Text.tertiary)
                    }
                }
                .width(70)
            }
        } rows: {
            ForEach(constraintRows) { row in
                TableRow(row)
            }
        }
        .contextMenu(forSelectionType: ConstraintRowModel.ID.self) { selection in
            constraintContextMenu(for: selection)
        } primaryAction: { selection in
            if let id = selection.first {
                openConstraintEditor(for: id)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .environment(\.defaultMinListRowHeight, 28)
    }

    @ViewBuilder
    private func constraintContextMenu(for selection: Set<ConstraintRowModel.ID>) -> some View {
        if selection.isEmpty {
            if viewModel.primaryKey == nil {
                Button("Add Primary Key") { presentPrimaryKeyEditor(isNew: true) }
            }
            Button("Add Unique Constraint") { presentNewUniqueConstraint() }
            Button("Add Check Constraint") { presentNewCheckConstraint() }
        } else if let id = selection.first, let row = constraintRows.first(where: { $0.id == id }) {
            Button("Edit \(row.kind.rawValue) Constraint") {
                openConstraintEditor(for: id)
            }
            Divider()
            Button("Delete Constraint", role: .destructive) {
                deleteConstraint(id: id, kind: row.kind)
            }
        }
    }

    private func openConstraintEditor(for id: UUID) {
        guard let row = constraintRows.first(where: { $0.id == id }) else { return }
        switch row.kind {
        case .primaryKey:
            presentPrimaryKeyEditor(isNew: false)
        case .unique:
            if let uq = viewModel.uniqueConstraints.first(where: { $0.id == id }) {
                presentUniqueConstraintEditor(for: uq)
            }
        case .check:
            if let ck = viewModel.checkConstraints.first(where: { $0.id == id }) {
                presentCheckConstraintEditor(for: ck)
            }
        }
    }

    private func deleteConstraint(id: UUID, kind: ConstraintRowModel.Kind) {
        switch kind {
        case .primaryKey:
            viewModel.removePrimaryKey()
        case .unique:
            if let uq = viewModel.uniqueConstraints.first(where: { $0.id == id }) {
                viewModel.removeUniqueConstraint(uq)
            }
        case .check:
            if let ck = viewModel.checkConstraints.first(where: { $0.id == id }) {
                viewModel.removeCheckConstraint(ck)
            }
        }
    }
}
