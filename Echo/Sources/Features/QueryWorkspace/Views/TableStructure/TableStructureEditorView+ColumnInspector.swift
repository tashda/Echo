import SwiftUI

extension TableStructureEditorView {

    internal func pushColumnInspector(ids: Set<TableStructureEditorViewModel.ColumnModel.ID>) {
        guard let id = ids.first,
              let column = visibleColumns.first(where: { $0.id == id }) else {
            pushTableInspector()
            return
        }

        var fields: [DatabaseObjectInspectorContent.Field] = [
            .init(label: "Name", value: column.name),
            .init(label: "Data Type", value: column.dataType),
            .init(label: "Nullable", value: column.isNullable ? "Yes" : "No"),
            .init(label: "Default", value: column.defaultValue ?? "\u{2014}")
        ]

        // Generated / computed column expression
        if let expr = column.generatedExpression, !expr.isEmpty {
            let label = viewModel.databaseType == .microsoftSQL ? "Computed" : "Generated"
            fields.append(.init(label: label, value: expr))
        }

        // Identity — MSSQL shows seed/increment, PG shows generation strategy
        if column.isIdentity {
            fields.append(.init(label: "Identity", value: "Yes"))
            if viewModel.databaseType == .microsoftSQL {
                fields.append(.init(label: "Seed", value: "\(column.identitySeed ?? 1)"))
                fields.append(.init(label: "Increment", value: "\(column.identityIncrement ?? 1)"))
            } else if viewModel.databaseType == .postgresql {
                let gen = column.identityGeneration ?? "ALWAYS"
                fields.append(.init(label: "Generation", value: gen.capitalized))
            }
        }

        if let collation = column.collation, !collation.isEmpty {
            fields.append(.init(label: "Collation", value: collation))
        }

        let pkColumns = Set(viewModel.primaryKey?.columns ?? [])
        if pkColumns.contains(column.name) {
            fields.append(.init(label: "Primary Key", value: "Yes"))
        }

        if let desc = columnChangeDescription(for: column) {
            fields.append(.init(label: "Changes", value: desc))
        }

        environmentState.dataInspectorContent = .databaseObject(DatabaseObjectInspectorContent(
            title: column.name,
            subtitle: column.dataType,
            fields: fields
        ))
    }

    private func pushTableInspector() {
        guard let props = viewModel.tableProperties else {
            environmentState.dataInspectorContent = nil
            return
        }

        var fields: [DatabaseObjectInspectorContent.Field] = [
            .init(label: "Table", value: "\(viewModel.schemaName).\(viewModel.tableName)")
        ]

        if let ff = props.fillfactor {
            fields.append(.init(label: "Fill Factor", value: "\(ff)"))
        }

        if viewModel.databaseType == .postgresql {
            if let ts = props.tablespace, !ts.isEmpty {
                fields.append(.init(label: "Tablespace", value: ts))
            }
            if let av = props.autovacuumEnabled {
                fields.append(.init(label: "Autovacuum", value: av ? "Enabled" : "Disabled"))
            }
            if let pw = props.parallelWorkers {
                fields.append(.init(label: "Parallel Workers", value: "\(pw)"))
            }
            if let tt = props.toastTupleTarget {
                fields.append(.init(label: "TOAST Tuple Target", value: "\(tt)"))
            }
        } else if viewModel.databaseType == .microsoftSQL {
            if let dc = props.dataCompression, !dc.isEmpty {
                fields.append(.init(label: "Data Compression", value: dc))
            }
            if let fg = props.filegroup, !fg.isEmpty {
                fields.append(.init(label: "Filegroup", value: fg))
            }
            if let le = props.lockEscalation, !le.isEmpty {
                fields.append(.init(label: "Lock Escalation", value: le))
            }
        }

        environmentState.dataInspectorContent = .databaseObject(DatabaseObjectInspectorContent(
            title: "\(viewModel.schemaName).\(viewModel.tableName)",
            subtitle: "Table Properties",
            fields: fields
        ))
    }
}
