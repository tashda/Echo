import Foundation
import SwiftUI
import Combine

enum TableStructureSection: String, CaseIterable, Identifiable {
    case columns
    case indexes
    case relations

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .columns: return "Columns"
        case .indexes: return "Indexes"
        case .relations: return "Relations"
        }
    }

    var order: Int {
        switch self {
        case .columns: return 0
        case .indexes: return 1
        case .relations: return 2
        }
    }
}

final class TableStructureEditorViewModel: ObservableObject {
    struct ColumnModel: Identifiable, Hashable {
        struct Snapshot: Hashable {
            let name: String
            let dataType: String
            let isNullable: Bool
            let defaultValue: String?
            let generatedExpression: String?
        }

        let id = UUID()
        let original: Snapshot?
        var name: String
        var dataType: String
        var isNullable: Bool
        var defaultValue: String?
        var generatedExpression: String?
        var isDeleted: Bool = false

        var isNew: Bool { original == nil }

        var referenceName: String {
            original?.name ?? name
        }

        var hasRename: Bool {
            guard let original else { return false }
            return original.name != name
        }

        var hasTypeChange: Bool {
            guard let original else { return false }
            return original.dataType != dataType
        }

        var hasNullabilityChange: Bool {
            guard let original else { return false }
            return original.isNullable != isNullable
        }

        var hasDefaultChange: Bool {
            guard let original else { return defaultValue != nil }
            return original.defaultValue != defaultValue
        }

        var hasExpressionChange: Bool {
            guard let original else { return generatedExpression != nil }
            return original.generatedExpression != generatedExpression
        }

        var isDirty: Bool {
            if isDeleted { return true }
            if isNew { return true }
            return hasRename || hasTypeChange || hasNullabilityChange || hasDefaultChange || hasExpressionChange
        }
    }

    struct IndexModel: Identifiable, Hashable {
        struct Column: Identifiable, Hashable {
            struct Snapshot: Hashable {
                let name: String
                let sortOrder: SortOrder
            }

            enum SortOrder: String, CaseIterable, Hashable {
                case ascending
                case descending

                var displayName: String {
                    switch self {
                    case .ascending: return "Ascending"
                    case .descending: return "Descending"
                    }
                }

                var sqlKeyword: String {
                    switch self {
                    case .ascending: return "ASC"
                    case .descending: return "DESC"
                    }
                }
            }

            let id = UUID()
            var name: String
            var sortOrder: SortOrder

            var snapshot: Snapshot {
                Snapshot(name: name, sortOrder: sortOrder)
            }
        }

        struct Snapshot: Hashable {
            let name: String
            let columns: [Column.Snapshot]
            let isUnique: Bool
            let filterCondition: String?
        }

        let id = UUID()
        let original: Snapshot?
        var name: String
        var columns: [Column]
        var isUnique: Bool
        var filterCondition: String
        var isDeleted: Bool = false

        var isNew: Bool { original == nil }

        var trimmedFilterCondition: String {
            filterCondition.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var effectiveFilterCondition: String? {
            let trimmed = trimmedFilterCondition
            return trimmed.isEmpty ? nil : trimmed
        }

        var isDirty: Bool {
            if isDeleted { return true }
            guard let original else { return true }

            if original.name != name { return true }
            if original.isUnique != isUnique { return true }

            let originalFilter = original.filterCondition?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if originalFilter != (effectiveFilterCondition ?? "") { return true }

            if original.columns.count != columns.count { return true }
            for (lhs, rhs) in zip(original.columns, columns.map { $0.snapshot }) {
                if lhs.name != rhs.name || lhs.sortOrder != rhs.sortOrder { return true }
            }

            return false
        }
    }

    struct UniqueConstraintModel: Identifiable, Hashable {
        struct Snapshot: Hashable {
            let name: String
            let columns: [String]
        }

        let id = UUID()
        let original: Snapshot?
        var name: String
        var columns: [String]
        var isDeleted: Bool = false
        var isNew: Bool { original == nil }
        var isDirty: Bool {
            if isDeleted { return true }
            guard let original else { return true }
            return original.name != name || original.columns != columns
        }
    }

    struct ForeignKeyModel: Identifiable, Hashable {
        struct Snapshot: Hashable {
            let name: String
            let columns: [String]
            let referencedSchema: String
            let referencedTable: String
            let referencedColumns: [String]
            let onUpdate: String?
            let onDelete: String?
        }

        let id = UUID()
        let original: Snapshot?
        var name: String
        var columns: [String]
        var referencedSchema: String
        var referencedTable: String
        var referencedColumns: [String]
        var onUpdate: String?
        var onDelete: String?
        var isDeleted: Bool = false

        var isNew: Bool { original == nil }
        var isDirty: Bool {
            if isDeleted { return true }
            guard let original else { return true }
            return original.name != name ||
                original.columns != columns ||
                original.referencedSchema != referencedSchema ||
                original.referencedTable != referencedTable ||
                original.referencedColumns != referencedColumns ||
                original.onUpdate != onUpdate ||
                original.onDelete != onDelete
        }
    }

    struct DependencyModel: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let baseColumns: [String]
        let referencedTable: String
        let referencedColumns: [String]
        let onUpdate: String?
        let onDelete: String?
    }

    struct PrimaryKeyModel: Identifiable, Hashable {
        struct Snapshot: Hashable {
            let name: String
            let columns: [String]
        }

        let id = UUID()
        let original: Snapshot?
        var name: String
        var columns: [String]

        var isDirty: Bool {
            guard let original else { return true }
            return original.name != name || original.columns != columns
        }
    }

    @Published var columns: [ColumnModel] = []
    @Published var indexes: [IndexModel] = []
    @Published var uniqueConstraints: [UniqueConstraintModel] = []
    @Published var foreignKeys: [ForeignKeyModel] = []
    @Published var dependencies: [DependencyModel] = []
    @Published var primaryKey: PrimaryKeyModel?
    @Published var requestedSection: TableStructureSection?

    @Published var isLoading: Bool = false
    @Published var isApplying: Bool = false
    @Published var lastError: String?
    @Published var lastSuccessMessage: String?

    let schemaName: String
    let tableName: String

    private let session: DatabaseSession
    private var originalPrimaryKeySnapshot: PrimaryKeyModel.Snapshot?
    private var removedPrimaryKeyName: String?

    init(schemaName: String, tableName: String, details: TableStructureDetails, session: DatabaseSession) {
        self.schemaName = schemaName
        self.tableName = tableName
        self.session = session
        apply(details: details)
    }

    func focusSection(_ section: TableStructureSection) {
        requestedSection = section
    }

    @MainActor
    func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let details = try await session.getTableStructureDetails(schema: schemaName, table: tableName)
            apply(details: details)
        } catch {
            lastError = error.localizedDescription
        }
    }

    @MainActor
    func applyChanges() async {
        lastError = nil
        lastSuccessMessage = nil

        let statements = generateStatements()
        guard !statements.isEmpty else {
            lastSuccessMessage = "No changes to apply"
            return
        }

        isApplying = true
        defer { isApplying = false }

        do {
            let executionPlan = ["BEGIN;"] + statements + ["COMMIT;"]
            do {
                for statement in executionPlan {
                    _ = try await session.executeUpdate(statement)
                }
            } catch {
                _ = try? await session.executeUpdate("ROLLBACK;")
                throw error
            }
            let refreshed = try await session.getTableStructureDetails(schema: schemaName, table: tableName)
            apply(details: refreshed)
            lastSuccessMessage = "Structure updated"
        } catch {
            lastError = error.localizedDescription
        }
    }

    var hasPendingChanges: Bool {
        if columns.contains(where: { $0.isDirty }) { return true }
        if indexes.contains(where: { $0.isDirty }) { return true }
        if uniqueConstraints.contains(where: { $0.isDirty }) { return true }
        if foreignKeys.contains(where: { $0.isDirty }) { return true }
        if primaryKey?.isDirty == true { return true }
        if removedPrimaryKeyName != nil { return true }
        return false
    }

    @discardableResult
    func addColumn() -> ColumnModel {
        let model = ColumnModel(
            original: nil,
            name: "new_column",
            dataType: "text",
            isNullable: true,
            defaultValue: nil,
            generatedExpression: nil
        )
        columns.append(model)
        return model
    }

    func removeColumn(_ column: ColumnModel) {
        if let index = columns.firstIndex(where: { $0.id == column.id }) {
            if columns[index].isNew {
                columns.remove(at: index)
            } else {
                columns[index].isDeleted = true
            }
        }
    }

    @discardableResult
    func addIndex(unique: Bool = false) -> IndexModel {
        let baseName = unique ? "new_unique" : "new_index"
        let availableColumns = columns.filter { !$0.isDeleted }
        let initialColumns: [IndexModel.Column]
        if let first = availableColumns.first {
            initialColumns = [IndexModel.Column(name: first.name, sortOrder: .ascending)]
        } else {
            initialColumns = []
        }

        let model = IndexModel(
            original: nil,
            name: baseName,
            columns: initialColumns,
            isUnique: unique,
            filterCondition: ""
        )
        indexes.append(model)
        return model
    }

    func removeIndex(_ index: IndexModel) {
        if let position = indexes.firstIndex(where: { $0.id == index.id }) {
            if indexes[position].isNew {
                indexes.remove(at: position)
            } else {
                indexes[position].isDeleted = true
            }
        }
    }

    @discardableResult
    func addUniqueConstraint() -> UniqueConstraintModel {
        let model = UniqueConstraintModel(
            original: nil,
            name: "uq_\(tableName)_\(uniqueConstraints.count + 1)",
            columns: []
        )
        uniqueConstraints.append(model)
        return model
    }

    func removeUniqueConstraint(_ constraint: UniqueConstraintModel) {
        if let position = uniqueConstraints.firstIndex(where: { $0.id == constraint.id }) {
            if uniqueConstraints[position].isNew {
                uniqueConstraints.remove(at: position)
            } else {
                uniqueConstraints[position].isDeleted = true
            }
        }
    }

    @discardableResult
    func addForeignKey() -> ForeignKeyModel {
        let model = ForeignKeyModel(
            original: nil,
            name: "fk_\(tableName)_\(foreignKeys.count + 1)",
            columns: [],
            referencedSchema: schemaName,
            referencedTable: tableName,
            referencedColumns: [],
            onUpdate: nil,
            onDelete: nil
        )
        foreignKeys.append(model)
        return model
    }

    func removeForeignKey(_ fk: ForeignKeyModel) {
        if let position = foreignKeys.firstIndex(where: { $0.id == fk.id }) {
            if foreignKeys[position].isNew {
                foreignKeys.remove(at: position)
            } else {
                foreignKeys[position].isDeleted = true
            }
        }
    }

    func removePrimaryKey() {
        if removedPrimaryKeyName == nil {
            removedPrimaryKeyName = originalPrimaryKeySnapshot?.name
        }
        primaryKey = nil
    }

    func clearPrimaryKeyRemoval() {
        removedPrimaryKeyName = nil
    }

    func reset(to details: TableStructureDetails) {
        apply(details: details)
    }

    private func apply(details: TableStructureDetails) {
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

    private func generateStatements() -> [String] {
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
                if !column.isNullable {
                    clause += " NOT NULL"
                }
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
            if let filter = index.effectiveFilterCondition {
                creation += " WHERE \(filter)"
            }
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
            if let onUpdate = fk.onUpdate, !onUpdate.isEmpty {
                clause += " ON UPDATE \(onUpdate)"
            }
            if let onDelete = fk.onDelete, !onDelete.isEmpty {
                clause += " ON DELETE \(onDelete)"
            }
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

    private func quoteIdentifier(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
