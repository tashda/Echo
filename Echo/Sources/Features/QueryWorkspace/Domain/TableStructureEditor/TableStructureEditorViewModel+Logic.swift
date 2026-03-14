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
        let dialect = dialectGenerator
        let qualifiedTable = dialect.qualifiedTable(schema: schemaName, table: tableName)
        var statements: [String] = []

        // Column drops
        for column in columns where column.isDeleted && !column.isNew {
            statements.append(dialect.dropColumn(table: qualifiedTable, column: column.referenceName))
        }

        // Column renames
        for column in columns where !column.isDeleted && column.hasRename {
            if let original = column.original {
                statements.append(dialect.renameColumn(table: qualifiedTable, from: original.name, to: column.name))
            }
        }

        // New columns and column modifications
        for column in columns where !column.isDeleted {
            if column.isNew {
                statements.append(dialect.addColumn(
                    table: qualifiedTable, name: column.name, dataType: column.dataType,
                    isNullable: column.isNullable, defaultValue: column.defaultValue,
                    generatedExpression: column.generatedExpression
                ))
                continue
            }

            if column.hasTypeChange {
                statements.append(dialect.alterColumnType(
                    table: qualifiedTable, column: column.name,
                    newType: column.dataType, isNullable: column.isNullable
                ))
            }
            if column.hasNullabilityChange && !column.hasTypeChange {
                statements.append(dialect.alterColumnNullability(
                    table: qualifiedTable, column: column.name,
                    isNullable: column.isNullable, currentType: column.dataType
                ))
            }
            if column.hasDefaultChange {
                if let value = column.defaultValue, !value.isEmpty {
                    statements.append(dialect.alterColumnSetDefault(table: qualifiedTable, column: column.name, defaultValue: value))
                } else {
                    statements.append(dialect.alterColumnDropDefault(table: qualifiedTable, column: column.name))
                }
            }
        }

        // Primary key
        if let pk = primaryKey {
            if let original = pk.original {
                if pk.isDirty {
                    statements.append(dialect.dropConstraint(table: qualifiedTable, name: original.name))
                    if !pk.columns.isEmpty {
                        statements.append(dialect.addPrimaryKey(table: qualifiedTable, name: pk.name, columns: pk.columns))
                    }
                }
            } else if !pk.columns.isEmpty {
                statements.append(dialect.addPrimaryKey(table: qualifiedTable, name: pk.name, columns: pk.columns))
            }
        } else if let removedName = removedPrimaryKeyName {
            statements.append(dialect.dropConstraint(table: qualifiedTable, name: removedName))
        }

        // Indexes
        for index in indexes where index.isDeleted && !index.isNew {
            if let original = index.original {
                statements.append(dialect.dropIndex(schema: schemaName, name: original.name, table: qualifiedTable))
            }
        }
        for index in indexes where !index.isDeleted {
            guard !index.columns.isEmpty else { continue }
            let cols = index.columns.map { (name: $0.name, sort: $0.sortOrder.sqlKeyword) }

            if index.isNew {
                statements.append(dialect.createIndex(table: qualifiedTable, name: index.name, columns: cols, isUnique: index.isUnique, filter: index.effectiveFilterCondition))
            } else if index.isDirty {
                if let original = index.original {
                    statements.append(dialect.dropIndex(schema: schemaName, name: original.name, table: qualifiedTable))
                }
                statements.append(dialect.createIndex(table: qualifiedTable, name: index.name, columns: cols, isUnique: index.isUnique, filter: index.effectiveFilterCondition))
            }
        }

        // Unique constraints
        for constraint in uniqueConstraints where constraint.isDeleted && !constraint.isNew {
            if let original = constraint.original {
                statements.append(dialect.dropConstraint(table: qualifiedTable, name: original.name))
            }
        }
        for constraint in uniqueConstraints where !constraint.isDeleted {
            guard !constraint.columns.isEmpty else { continue }
            if constraint.isNew {
                statements.append(dialect.addUniqueConstraint(table: qualifiedTable, name: constraint.name, columns: constraint.columns))
            } else if constraint.isDirty, let original = constraint.original {
                statements.append(dialect.dropConstraint(table: qualifiedTable, name: original.name))
                statements.append(dialect.addUniqueConstraint(table: qualifiedTable, name: constraint.name, columns: constraint.columns))
            }
        }

        // Foreign keys
        for fk in foreignKeys where fk.isDeleted && !fk.isNew {
            if let original = fk.original {
                statements.append(dialect.dropConstraint(table: qualifiedTable, name: original.name))
            }
        }
        for fk in foreignKeys where !fk.isDeleted {
            guard !fk.columns.isEmpty, !fk.referencedColumns.isEmpty else { continue }

            if fk.isNew {
                statements.append(dialect.addForeignKey(table: qualifiedTable, name: fk.name, columns: fk.columns, referencedSchema: fk.referencedSchema, referencedTable: fk.referencedTable, referencedColumns: fk.referencedColumns, onUpdate: fk.onUpdate, onDelete: fk.onDelete))
            } else if fk.isDirty {
                if let original = fk.original {
                    statements.append(dialect.dropConstraint(table: qualifiedTable, name: original.name))
                }
                statements.append(dialect.addForeignKey(table: qualifiedTable, name: fk.name, columns: fk.columns, referencedSchema: fk.referencedSchema, referencedTable: fk.referencedTable, referencedColumns: fk.referencedColumns, onUpdate: fk.onUpdate, onDelete: fk.onDelete))
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
}
