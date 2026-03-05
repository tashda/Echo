import Foundation

extension TableStructureEditorViewModel {
    
    func reset(to details: TableStructureDetails) {
        apply(details: details)
    }

    internal func apply(details: TableStructureDetails) {
        columns = details.columns.map { column in
            ColumnModel(
                original: ColumnModel.Snapshot(
                    name: column.name,
                    dataType: column.dataType,
                    isNullable: column.isNullable,
                    defaultValue: column.defaultValue,
                    generatedExpression: column.generatedExpression
                ),
                name: column.name,
                dataType: column.dataType,
                isNullable: column.isNullable,
                defaultValue: column.defaultValue,
                generatedExpression: column.generatedExpression
            )
        }

        indexes = details.indexes.map { index in
            let columns = index.columns.map { column in
                IndexModel.Column(name: column.name, sortOrder: column.sortOrder == .descending ? .descending : .ascending)
            }
            return IndexModel(
                original: IndexModel.Snapshot(
                    name: index.name,
                    columns: columns.map { $0.snapshot },
                    isUnique: index.isUnique,
                    filterCondition: index.filterCondition
                ),
                name: index.name,
                columns: columns,
                isUnique: index.isUnique,
                filterCondition: index.filterCondition ?? ""
            )
        }

        uniqueConstraints = details.uniqueConstraints.map { constraint in
            UniqueConstraintModel(
                original: UniqueConstraintModel.Snapshot(name: constraint.name, columns: constraint.columns),
                name: constraint.name,
                columns: constraint.columns
            )
        }

        foreignKeys = details.foreignKeys.map { fk in
            ForeignKeyModel(
                original: ForeignKeyModel.Snapshot(
                    name: fk.name,
                    columns: fk.columns,
                    referencedSchema: fk.referencedSchema,
                    referencedTable: fk.referencedTable,
                    referencedColumns: fk.referencedColumns,
                    onUpdate: fk.onUpdate,
                    onDelete: fk.onDelete
                ),
                name: fk.name,
                columns: fk.columns,
                referencedSchema: fk.referencedSchema,
                referencedTable: fk.referencedTable,
                referencedColumns: fk.referencedColumns,
                onUpdate: fk.onUpdate,
                onDelete: fk.onDelete
            )
        }

        dependencies = details.dependencies.map { dependency in
            DependencyModel(
                name: dependency.name,
                baseColumns: dependency.baseColumns,
                referencedTable: dependency.referencedTable,
                referencedColumns: dependency.referencedColumns,
                onUpdate: dependency.onUpdate,
                onDelete: dependency.onDelete
            )
        }

        if let pk = details.primaryKey {
            primaryKey = PrimaryKeyModel(
                original: PrimaryKeyModel.Snapshot(name: pk.name, columns: pk.columns),
                name: pk.name,
                columns: pk.columns
            )
            originalPrimaryKeySnapshot = primaryKey?.original
            removedPrimaryKeyName = nil
        } else {
            primaryKey = nil
            originalPrimaryKeySnapshot = nil
            removedPrimaryKeyName = nil
        }
    }

    internal func generateStatements() -> [String] {
        var statements: [String] = []
        let qualifiedTable = "\(quoteIdentifier(schemaName)).\(quoteIdentifier(tableName))"

        // Columns: drops first
        for column in columns where column.isDeleted && !column.isNew {
            statements.append("ALTER TABLE \(qualifiedTable) DROP COLUMN \(quoteIdentifier(column.referenceName)) CASCADE;")
        }

        // Column renames
        for column in columns where !column.isDeleted && column.hasRename {
            if let original = column.original {
                statements.append("ALTER TABLE \(qualifiedTable) RENAME COLUMN \(quoteIdentifier(original.name)) TO \(quoteIdentifier(column.name));")
            }
        }

        // Column type/nullability/default adjustments
        for column in columns where !column.isDeleted {
            if column.isNew {
                var clause = "ALTER TABLE \(qualifiedTable) ADD COLUMN \(quoteIdentifier(column.name)) \(column.dataType)"
                if !column.isNullable { clause += " NOT NULL" }
                if let expression = column.generatedExpression, !expression.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    clause += " GENERATED ALWAYS AS (\(expression)) STORED"
                } else if let defaultValue = column.defaultValue, !defaultValue.isEmpty {
                    clause += " DEFAULT \(defaultValue)"
                }
                clause += ";"
                statements.append(clause)
                continue
            }

            let targetName = quoteIdentifier(column.name)
            if column.hasTypeChange {
                statements.append("ALTER TABLE \(qualifiedTable) ALTER COLUMN \(targetName) TYPE \(column.dataType);")
            }
            if column.hasNullabilityChange {
                let clause = column.isNullable ? "DROP NOT NULL" : "SET NOT NULL"
                statements.append("ALTER TABLE \(qualifiedTable) ALTER COLUMN \(targetName) \(clause);")
            }
            if column.hasDefaultChange {
                if let value = column.defaultValue, !value.isEmpty {
                    statements.append("ALTER TABLE \(qualifiedTable) ALTER COLUMN \(targetName) SET DEFAULT \(value);")
                } else {
                    statements.append("ALTER TABLE \(qualifiedTable) ALTER COLUMN \(targetName) DROP DEFAULT;")
                }
            }
        }

        // Primary key updates
        if let pk = primaryKey {
            if let original = pk.original {
                if pk.isDirty {
                    statements.append("ALTER TABLE \(qualifiedTable) DROP CONSTRAINT \(quoteIdentifier(original.name));")
                    if !pk.columns.isEmpty {
                        let cols = pk.columns.map(quoteIdentifier).joined(separator: ", ")
                        statements.append("ALTER TABLE \(qualifiedTable) ADD CONSTRAINT \(quoteIdentifier(pk.name)) PRIMARY KEY (\(cols));")
                    }
                }
            } else if !pk.columns.isEmpty {
                let cols = pk.columns.map(quoteIdentifier).joined(separator: ", ")
                statements.append("ALTER TABLE \(qualifiedTable) ADD CONSTRAINT \(quoteIdentifier(pk.name)) PRIMARY KEY (\(cols));")
            }
        } else if let removedName = removedPrimaryKeyName {
            statements.append("ALTER TABLE \(qualifiedTable) DROP CONSTRAINT \(quoteIdentifier(removedName));")
        }

        // Indexes
        for index in indexes where index.isDeleted && !index.isNew {
            if let original = index.original {
                statements.append("DROP INDEX IF EXISTS \(quoteIdentifier(schemaName)).\(quoteIdentifier(original.name));")
            }
        }
        for index in indexes where !index.isDeleted {
            guard !index.columns.isEmpty else { continue }
            let columnsClause = index.columns
                .map { "\(quoteIdentifier($0.name)) \($0.sortOrder.sqlKeyword)" }
                .joined(separator: ", ")

            var creation = "CREATE \(index.isUnique ? "UNIQUE " : "")INDEX \(quoteIdentifier(index.name)) ON \(qualifiedTable) (\(columnsClause))"
            if let filter = index.effectiveFilterCondition { creation += " WHERE \(filter)" }
            creation += ";"

            if index.isNew {
                statements.append(creation)
            } else if index.isDirty {
                if let original = index.original {
                    statements.append("DROP INDEX IF EXISTS \(quoteIdentifier(schemaName)).\(quoteIdentifier(original.name));")
                }
                statements.append(creation)
            }
        }

        // Unique constraints
        for constraint in uniqueConstraints where constraint.isDeleted && !constraint.isNew {
            if let original = constraint.original {
                statements.append("ALTER TABLE \(qualifiedTable) DROP CONSTRAINT \(quoteIdentifier(original.name));")
            }
        }
        for constraint in uniqueConstraints where !constraint.isDeleted {
            guard !constraint.columns.isEmpty else { continue }
            let cols = constraint.columns.map(quoteIdentifier).joined(separator: ", ")
            if constraint.isNew {
                statements.append("ALTER TABLE \(qualifiedTable) ADD CONSTRAINT \(quoteIdentifier(constraint.name)) UNIQUE (\(cols));")
            } else if constraint.isDirty, let original = constraint.original {
                statements.append("ALTER TABLE \(qualifiedTable) DROP CONSTRAINT \(quoteIdentifier(original.name));")
                statements.append("ALTER TABLE \(qualifiedTable) ADD CONSTRAINT \(quoteIdentifier(constraint.name)) UNIQUE (\(cols));")
            }
        }

        // Foreign keys
        for fk in foreignKeys where fk.isDeleted && !fk.isNew {
            if let original = fk.original {
                statements.append("ALTER TABLE \(qualifiedTable) DROP CONSTRAINT \(quoteIdentifier(original.name));")
            }
        }
        for fk in foreignKeys where !fk.isDeleted {
            guard !fk.columns.isEmpty, !fk.referencedColumns.isEmpty else { continue }
            let columnsList = fk.columns.map(quoteIdentifier).joined(separator: ", ")
            let referencedTableQualified = "\(quoteIdentifier(fk.referencedSchema)).\(quoteIdentifier(fk.referencedTable))"
            let referencedColumns = fk.referencedColumns.map(quoteIdentifier).joined(separator: ", ")
            var clause = "ALTER TABLE \(qualifiedTable) ADD CONSTRAINT \(quoteIdentifier(fk.name)) FOREIGN KEY (\(columnsList)) REFERENCES \(referencedTableQualified) (\(referencedColumns))"
            if let onUpdate = fk.onUpdate, !onUpdate.isEmpty { clause += " ON UPDATE \(onUpdate)" }
            if let onDelete = fk.onDelete, !onDelete.isEmpty { clause += " ON DELETE \(onDelete)" }
            clause += ";"

            if fk.isNew {
                statements.append(clause)
            } else if fk.isDirty {
                if let original = fk.original {
                    statements.append("ALTER TABLE \(qualifiedTable) DROP CONSTRAINT \(quoteIdentifier(original.name));")
                }
                statements.append(clause)
            }
        }

        return statements
    }

    func estimatedMemoryUsageBytes() -> Int {
        let baseOverhead = 48 * 1024
        
        var columnBytes = 0
        for col in columns {
            let stringSum = col.name.utf8.count + col.dataType.utf8.count + (col.defaultValue?.utf8.count ?? 0) + (col.generatedExpression?.utf8.count ?? 0)
            columnBytes += 256 + (stringSum * 2)
        }
        
        var indexBytes = 0
        for idx in indexes {
            let filterLen = idx.filterCondition.utf8.count
            var colLenSum = 0
            for col in idx.columns {
                colLenSum += col.name.utf8.count * 2 + 64
            }
            indexBytes += 320 + (idx.name.utf8.count + filterLen) * 2 + colLenSum
        }
        
        var uniqueBytes = 0
        for uq in uniqueConstraints {
            var colLenSum = 0
            for col in uq.columns {
                colLenSum += col.utf8.count * 2 + 32
            }
            uniqueBytes += 240 + uq.name.utf8.count * 2 + colLenSum
        }
        
        var foreignKeyBytes = 0
        for fk in foreignKeys {
            let nameSum = fk.name.utf8.count + fk.referencedSchema.utf8.count + fk.referencedTable.utf8.count + (fk.onUpdate?.utf8.count ?? 0) + (fk.onDelete?.utf8.count ?? 0)
            var colLenSum = 0
            for c in fk.columns { colLenSum += c.utf8.count * 2 + 32 }
            for c in fk.referencedColumns { colLenSum += c.utf8.count * 2 + 32 }
            foreignKeyBytes += 360 + (nameSum * 2) + colLenSum
        }
        
        return baseOverhead + columnBytes + indexBytes + uniqueBytes + foreignKeyBytes
    }

    private func quoteIdentifier(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
