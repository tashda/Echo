import Foundation

protocol DatabaseScriptProvider {
    func quoteIdentifier(_ identifier: String) -> String
    func qualifiedName(schema: String, name: String) -> String
    func scriptActions(for objectType: SchemaObjectInfo.ObjectType) -> [ScriptAction]
    func executeStatement(for objectType: SchemaObjectInfo.ObjectType, qualifiedName: String) -> String
    func truncateStatement(qualifiedName: String) -> String
    func renameStatement(for object: SchemaObjectInfo, qualifiedName: String, newName: String?) -> String?
    func dropStatement(for object: SchemaObjectInfo, qualifiedName: String, keyword: String, includeIfExists: Bool, triggerTargetName: String) -> String
    func alterStatement(for object: SchemaObjectInfo, qualifiedName: String, keyword: String) -> String
    func alterTableStatement(qualifiedName: String) -> String
    func selectStatement(qualifiedName: String, columnLines: String, limit: Int?, offset: Int) -> String
    var supportsTruncateTable: Bool { get }
    var renameMenuLabel: String { get }
}

extension DatabaseScriptProvider {
    func qualifiedName(schema: String, name: String) -> String {
        let trimmedSchema = schema.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSchema.isEmpty {
            return quoteIdentifier(name)
        }
        return "\(quoteIdentifier(trimmedSchema)).\(quoteIdentifier(name))"
    }

    func triggerTargetName(for object: SchemaObjectInfo) -> String {
        guard let triggerTable = object.triggerTable, !triggerTable.isEmpty else {
            return qualifiedName(schema: object.schema, name: "<table_name>")
        }
        if triggerTable.contains(".") {
            let parts = triggerTable.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: true)
            if parts.count == 2 {
                return qualifiedName(schema: String(parts[0]), name: String(parts[1]))
            }
        }
        return qualifiedName(schema: object.schema, name: triggerTable)
    }

    func qualifiedDestinationName(schema: String, newName: String) -> String {
        let trimmedSchema = schema.trimmingCharacters(in: .whitespacesAndNewlines)
        let quotedNewName = quoteIdentifier(newName)
        guard !trimmedSchema.isEmpty else { return quotedNewName }
        return "\(quoteIdentifier(trimmedSchema)).\(quotedNewName)"
    }

    func qualifiedForStoredProcedures(schema: String, name: String) -> String {
        let trimmedSchema = schema.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSchema.isEmpty else { return name }
        return "\(trimmedSchema).\(name)"
    }

    var renameMenuLabel: String { "Rename" }
}
