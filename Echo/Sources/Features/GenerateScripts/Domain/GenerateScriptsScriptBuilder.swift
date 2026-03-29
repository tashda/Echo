import Foundation

enum GenerateScriptsScriptBuilder {
    static func categoryGroups(for objects: [GenerateScriptsObject]) -> [(category: String, objects: [GenerateScriptsObject])] {
        let grouped = Dictionary(grouping: objects, by: \.category)
        let categoryOrder = SchemaObjectInfo.ObjectType.allCases.map(\.pluralDisplayName)

        return categoryOrder.compactMap { category in
            guard let objects = grouped[category], !objects.isEmpty else { return nil }
            return (
                category: category,
                objects: objects.sorted { lhs, rhs in
                    if lhs.schema == rhs.schema {
                        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                    }
                    return lhs.qualifiedName.localizedStandardCompare(rhs.qualifiedName) == .orderedAscending
                }
            )
        }
    }

    static func defaultSelection(from objects: [GenerateScriptsObject], preferredObjectID: String?) -> Set<String> {
        if let preferredObjectID, objects.contains(where: { $0.id == preferredObjectID }) {
            return [preferredObjectID]
        }
        return Set(objects.map(\.id))
    }

    static func objectGenerationOrder(
        from objects: [GenerateScriptsObject],
        selectedObjectIDs: Set<String>,
        includeTriggers: Bool
    ) -> [GenerateScriptsObject] {
        let typeOrder: [SchemaObjectInfo.ObjectType] = [
            .table,
            .view,
            .procedure,
            .function,
            .trigger,
            .sequence,
            .synonym,
            .type,
            .materializedView,
            .extension
        ]
        let orderMap = Dictionary(uniqueKeysWithValues: typeOrder.enumerated().map { ($1, $0) })

        return objects
            .filter { selectedObjectIDs.contains($0.id) }
            .filter { includeTriggers || $0.type != .trigger }
            .sorted { lhs, rhs in
                let lhsOrder = orderMap[lhs.type] ?? Int.max
                let rhsOrder = orderMap[rhs.type] ?? Int.max
                if lhsOrder != rhsOrder {
                    return lhsOrder < rhsOrder
                }
                if lhs.schema == rhs.schema {
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
                return lhs.qualifiedName.localizedStandardCompare(rhs.qualifiedName) == .orderedAscending
            }
    }

    static func dataSelectSQL(for object: GenerateScriptsObject, databaseType: DatabaseType) -> String {
        let qualifiedTable = qualifiedReference(for: object, databaseType: databaseType)
        return "SELECT * FROM \(qualifiedTable)"
    }

    static func insertStatements(
        for result: QueryResultSet,
        object: GenerateScriptsObject,
        databaseType: DatabaseType
    ) -> String {
        guard !result.rows.isEmpty else {
            return "-- No rows found for \(object.qualifiedName)"
        }

        let qualifiedTable = qualifiedReference(for: object, databaseType: databaseType)
        let quotedColumns = result.columns
            .map(\.name)
            .map { quoteIdentifier($0, databaseType: databaseType) }
            .joined(separator: ", ")

        return result.rows.map { row in
            let values = row.map(sqlLiteral).joined(separator: ", ")
            return "INSERT INTO \(qualifiedTable) (\(quotedColumns)) VALUES (\(values));"
        }
        .joined(separator: "\n")
    }

    static func quoteIdentifier(_ identifier: String, databaseType: DatabaseType) -> String {
        switch databaseType {
        case .mysql:
            return "`\(identifier.replacingOccurrences(of: "`", with: "``"))`"
        case .microsoftSQL:
            return "[\(identifier.replacingOccurrences(of: "]", with: "]]"))]"
        case .postgresql, .sqlite:
            return "\"\(identifier.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
    }

    static func qualifiedReference(for object: GenerateScriptsObject, databaseType: DatabaseType) -> String {
        if object.schema.isEmpty || databaseType == .sqlite {
            return quoteIdentifier(object.name, databaseType: databaseType)
        }
        return "\(quoteIdentifier(object.schema, databaseType: databaseType)).\(quoteIdentifier(object.name, databaseType: databaseType))"
    }

    private static func sqlLiteral(_ value: String?) -> String {
        guard let value else { return "NULL" }
        if value.isEmpty { return "''" }
        if value.uppercased() == "NULL" { return "NULL" }
        if Int(value) != nil || Double(value) != nil { return value }
        let lowercased = value.lowercased()
        if lowercased == "true" || lowercased == "false" {
            return lowercased.uppercased()
        }
        return "'" + value.replacingOccurrences(of: "'", with: "''") + "'"
    }
}
