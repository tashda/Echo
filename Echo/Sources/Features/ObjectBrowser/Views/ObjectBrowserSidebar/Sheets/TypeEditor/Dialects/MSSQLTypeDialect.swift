import Foundation
import SQLServerKit

struct MSSQLTypeDialect: TypeEditorDialect, Sendable {

    var supportsComposite: Bool { false }
    var supportsEnum: Bool { false }
    var supportsRange: Bool { false }
    var supportsDomain: Bool { false }
    var supportsOwnership: Bool { false }
    var supportsComments: Bool { true }

    func loadMetadata(session: any DatabaseSession, schema: String, name: String, category: TypeCategory) async throws -> TypeEditorMetadata {
        guard let mssql = session as? SQLServerSessionAdapter else {
            throw ViewEditorDialectError.unsupportedSession
        }

        var metadata = TypeEditorMetadata(
            name: name, owner: "", description: "",
            attributes: [TypeAttributeDraft()], enumValues: [EnumValueDraft()],
            subtype: "", subtypeOpClass: "", collation: "",
            baseDataType: "", defaultValue: "", isNotNull: false, domainConstraints: []
        )

        if let details = try await mssql.client.metadata.userTypeDetails(schema: schema, name: name) {
            metadata.baseDataType = details.baseType ?? ""
            metadata.description = details.comment ?? ""

            // For table types, load columns as attributes
            if details.kind == .tableType {
                let tableTypes = try await mssql.client.types.listUserDefinedTableTypes(schema: schema)
                if let tableDef = tableTypes.first(where: { $0.name == name }) {
                    metadata.attributes = tableDef.columns.map { col in
                        TypeAttributeDraft(name: col.name, dataType: col.dataType.sqlLiteral)
                    }
                }
            }
        }

        return metadata
    }

    func generateSQL(context: TypeEditorSQLContext) -> String {
        let qualified = "\(quoteIdentifier(context.schema)).\(quoteIdentifier(context.name))"

        // MSSQL only supports alias types and table types
        if !context.baseDataType.isEmpty {
            // Alias type
            if context.isEditing {
                return "-- Alias types cannot be altered. Drop and recreate.\nDROP TYPE IF EXISTS \(qualified);\n\nCREATE TYPE \(qualified) FROM \(context.baseDataType)\(context.isNotNull ? " NOT NULL" : "");"
            } else {
                return "CREATE TYPE \(qualified) FROM \(context.baseDataType)\(context.isNotNull ? " NOT NULL" : "");"
            }
        } else {
            // Table type
            let validAttrs = context.attributes.filter {
                !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !$0.dataType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            let colList = validAttrs.map { "    \(quoteIdentifier($0.name)) \($0.dataType)" }.joined(separator: ",\n")

            if context.isEditing {
                return "-- Table types cannot be altered. Drop and recreate.\nDROP TYPE IF EXISTS \(qualified);\n\nCREATE TYPE \(qualified) AS TABLE (\n\(colList)\n);"
            } else {
                return "CREATE TYPE \(qualified) AS TABLE (\n\(colList)\n);"
            }
        }
    }

    func quoteIdentifier(_ identifier: String) -> String {
        let escaped = identifier.replacingOccurrences(of: "]", with: "]]")
        return "[\(escaped)]"
    }
}
