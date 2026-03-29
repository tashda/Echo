import Foundation
import Observation

/// Visual query builder state. Users add tables, select columns, define joins,
/// and set WHERE/ORDER BY conditions. SQL is generated in real-time.
@Observable @MainActor
final class VisualQueryBuilderViewModel {

    // MARK: - Table Nodes

    struct TableNode: Identifiable {
        let id = UUID()
        let schema: String
        let name: String
        let columns: [ColumnInfo]
        var position: CGPoint
        var selectedColumns: Set<String>
        var alias: String

        var qualifiedName: String { "\(schema).\(name)" }
    }

    // MARK: - Joins

    struct JoinDef: Identifiable {
        let id = UUID()
        var sourceTableID: UUID
        var sourceColumn: String
        var targetTableID: UUID
        var targetColumn: String
        var joinType: JoinType
    }

    enum JoinType: String, CaseIterable {
        case inner = "INNER JOIN"
        case left = "LEFT JOIN"
        case right = "RIGHT JOIN"
        case full = "FULL OUTER JOIN"
        case cross = "CROSS JOIN"
    }

    // MARK: - Conditions

    struct WhereCondition: Identifiable {
        let id = UUID()
        var tableID: UUID
        var column: String
        var operatorType: String
        var value: String
        var connector: String // AND / OR
    }

    struct OrderByClause: Identifiable {
        let id = UUID()
        var tableID: UUID
        var column: String
        var direction: String // ASC / DESC
    }

    // MARK: - State

    var tables: [TableNode] = []
    var joins: [JoinDef] = []
    var whereConditions: [WhereCondition] = []
    var orderByClauses: [OrderByClause] = []
    var limit: Int?
    var distinct = false

    var isLoadingTables = false
    var availableTables: [SchemaObjectInfo] = []
    var availableSchemas: [String] = []
    var selectedSchema: String = ""

    let databaseType: DatabaseType
    let session: DatabaseSession

    // MARK: - Computed

    var generatedSQL: String {
        buildSQL()
    }

    var hasSelectedColumns: Bool {
        tables.contains { !$0.selectedColumns.isEmpty }
    }

    init(databaseType: DatabaseType, session: DatabaseSession) {
        self.databaseType = databaseType
        self.session = session
    }

    // MARK: - Schema/Table Discovery

    func loadSchemas() async {
        isLoadingTables = true
        do {
            availableSchemas = try await session.listSchemas()
            if selectedSchema.isEmpty, let first = availableSchemas.first {
                selectedSchema = first
            }
            await loadTablesForSchema()
        } catch {
            // Silently handle — user can retry
        }
        isLoadingTables = false
    }

    func loadTablesForSchema() async {
        guard !selectedSchema.isEmpty else { return }
        do {
            let objects = try await session.listTablesAndViews(schema: selectedSchema)
            availableTables = objects.filter { $0.type == .table || $0.type == .view }
        } catch {
            availableTables = []
        }
    }

    // MARK: - Add/Remove Tables

    func addTable(_ object: SchemaObjectInfo, at position: CGPoint) async {
        guard !tables.contains(where: { $0.schema == object.schema && $0.name == object.name }) else { return }

        do {
            let columns = try await session.getTableSchema(object.name, schemaName: object.schema)
            let alias = generateAlias(for: object.name)
            let node = TableNode(
                schema: object.schema,
                name: object.name,
                columns: columns,
                position: position,
                selectedColumns: Set(columns.map(\.name)),
                alias: alias
            )
            tables.append(node)
        } catch {
            // Could not load columns — add with empty
            let alias = generateAlias(for: object.name)
            let node = TableNode(
                schema: object.schema,
                name: object.name,
                columns: [],
                position: position,
                selectedColumns: [],
                alias: alias
            )
            tables.append(node)
        }
    }

    func removeTable(_ id: UUID) {
        tables.removeAll(where: { $0.id == id })
        joins.removeAll(where: { $0.sourceTableID == id || $0.targetTableID == id })
        whereConditions.removeAll(where: { $0.tableID == id })
        orderByClauses.removeAll(where: { $0.tableID == id })
    }

    // MARK: - Column Selection

    func toggleColumn(tableID: UUID, column: String) {
        guard let idx = tables.firstIndex(where: { $0.id == tableID }) else { return }
        if tables[idx].selectedColumns.contains(column) {
            tables[idx].selectedColumns.remove(column)
        } else {
            tables[idx].selectedColumns.insert(column)
        }
    }

    func selectAllColumns(tableID: UUID) {
        guard let idx = tables.firstIndex(where: { $0.id == tableID }) else { return }
        tables[idx].selectedColumns = Set(tables[idx].columns.map(\.name))
    }

    func deselectAllColumns(tableID: UUID) {
        guard let idx = tables.firstIndex(where: { $0.id == tableID }) else { return }
        tables[idx].selectedColumns.removeAll()
    }

    // MARK: - Joins

    func addJoin(sourceTableID: UUID, sourceColumn: String, targetTableID: UUID, targetColumn: String, type: JoinType = .inner) {
        let join = JoinDef(
            sourceTableID: sourceTableID,
            sourceColumn: sourceColumn,
            targetTableID: targetTableID,
            targetColumn: targetColumn,
            joinType: type
        )
        joins.append(join)
    }

    func removeJoin(_ id: UUID) {
        joins.removeAll(where: { $0.id == id })
    }

    // MARK: - WHERE

    func addWhereCondition(tableID: UUID, column: String, op: String = "=", value: String = "") {
        let condition = WhereCondition(
            tableID: tableID,
            column: column,
            operatorType: op,
            value: value,
            connector: whereConditions.isEmpty ? "" : "AND"
        )
        whereConditions.append(condition)
    }

    func removeWhereCondition(_ id: UUID) {
        whereConditions.removeAll(where: { $0.id == id })
    }

    // MARK: - ORDER BY

    func addOrderBy(tableID: UUID, column: String, direction: String = "ASC") {
        let clause = OrderByClause(tableID: tableID, column: column, direction: direction)
        orderByClauses.append(clause)
    }

    func removeOrderBy(_ id: UUID) {
        orderByClauses.removeAll(where: { $0.id == id })
    }

    // MARK: - SQL Generation

    private func buildSQL() -> String {
        guard !tables.isEmpty else { return "-- Add tables to start building a query" }

        var sql = "SELECT"
        if distinct { sql += " DISTINCT" }

        // Columns
        let columnList = tables.flatMap { table in
            table.selectedColumns.sorted().map { col in
                let prefix = tables.count > 1 ? "\(quoteIdentifier(table.alias))." : ""
                return "\(prefix)\(quoteIdentifier(col))"
            }
        }

        if columnList.isEmpty {
            sql += " *"
        } else {
            sql += "\n    " + columnList.joined(separator: ",\n    ")
        }

        // FROM
        let firstTable = tables[0]
        sql += "\nFROM \(qualifiedTableName(firstTable))"
        if tables.count > 1 {
            sql += " \(quoteIdentifier(firstTable.alias))"
        }

        // JOINs
        for join in joins {
            guard let sourceTable = tables.first(where: { $0.id == join.sourceTableID }),
                  let targetTable = tables.first(where: { $0.id == join.targetTableID }) else { continue }

            sql += "\n\(join.joinType.rawValue) \(qualifiedTableName(targetTable)) \(quoteIdentifier(targetTable.alias))"
            sql += "\n    ON \(quoteIdentifier(sourceTable.alias)).\(quoteIdentifier(join.sourceColumn))"
            sql += " = \(quoteIdentifier(targetTable.alias)).\(quoteIdentifier(join.targetColumn))"
        }

        // Remaining tables without explicit joins (implicit cross join)
        let joinedTableIDs = Set(joins.flatMap { [$0.sourceTableID, $0.targetTableID] })
        for table in tables.dropFirst() where !joinedTableIDs.contains(table.id) {
            sql += ",\n    \(qualifiedTableName(table)) \(quoteIdentifier(table.alias))"
        }

        // WHERE
        if !whereConditions.isEmpty {
            sql += "\nWHERE "
            for (idx, condition) in whereConditions.enumerated() {
                if idx > 0 {
                    sql += "\n    \(condition.connector) "
                }
                guard let table = tables.first(where: { $0.id == condition.tableID }) else { continue }
                let prefix = tables.count > 1 ? "\(quoteIdentifier(table.alias))." : ""
                sql += "\(prefix)\(quoteIdentifier(condition.column)) \(condition.operatorType) \(condition.value)"
            }
        }

        // ORDER BY
        if !orderByClauses.isEmpty {
            sql += "\nORDER BY "
            let clauses = orderByClauses.compactMap { clause -> String? in
                guard let table = tables.first(where: { $0.id == clause.tableID }) else { return nil }
                let prefix = tables.count > 1 ? "\(quoteIdentifier(table.alias))." : ""
                return "\(prefix)\(quoteIdentifier(clause.column)) \(clause.direction)"
            }
            sql += clauses.joined(separator: ", ")
        }

        // LIMIT
        if let limit {
            switch databaseType {
            case .microsoftSQL:
                // Inject TOP after SELECT
                let topClause = " TOP \(limit)"
                if let range = sql.range(of: "SELECT DISTINCT") {
                    sql.insert(contentsOf: topClause, at: range.upperBound)
                } else if let range = sql.range(of: "SELECT") {
                    sql.insert(contentsOf: topClause, at: range.upperBound)
                }
            default:
                sql += "\nLIMIT \(limit)"
            }
        }

        sql += ";"
        return sql
    }

    // MARK: - Helpers

    private func quoteIdentifier(_ name: String) -> String {
        switch databaseType {
        case .microsoftSQL: return "[\(name)]"
        case .mysql: return "`\(name)`"
        default: return "\"\(name)\""
        }
    }

    private func qualifiedTableName(_ table: TableNode) -> String {
        switch databaseType {
        case .microsoftSQL: return "[\(table.schema)].[\(table.name)]"
        case .postgresql: return "\"\(table.schema)\".\"\(table.name)\""
        case .mysql: return "`\(table.name)`"
        case .sqlite: return "\"\(table.name)\""
        }
    }

    private func generateAlias(for tableName: String) -> String {
        let base = String(tableName.prefix(1)).lowercased()
        let existing = Set(tables.map(\.alias))
        if !existing.contains(base) { return base }
        for i in 1...99 {
            let candidate = "\(base)\(i)"
            if !existing.contains(candidate) { return candidate }
        }
        return tableName
    }
}
