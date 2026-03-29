import Foundation

extension GenerateScriptsScriptBuilder {
    static func preamble(
        databaseName: String,
        databaseType: DatabaseType,
        includeUseDatabase: Bool
    ) -> String {
        guard includeUseDatabase else { return "" }

        switch databaseType {
        case .microsoftSQL:
            return "USE [\(databaseName.replacingOccurrences(of: "]", with: "]]"))];\nGO\n\n"
        case .mysql:
            return "USE `\(databaseName.replacingOccurrences(of: "`", with: "``"))`;\n\n"
        case .postgresql, .sqlite:
            return ""
        }
    }

    static func wrappedDefinition(
        _ definition: String,
        object: GenerateScriptsObject,
        databaseType: DatabaseType,
        checkExistence: Bool,
        scriptDropAndCreate: Bool
    ) -> String {
        let trimmedDefinition = definition.trimmingCharacters(in: .whitespacesAndNewlines)
        var lines: [String] = []

        if scriptDropAndCreate, let dropStatement = dropStatement(for: object, databaseType: databaseType, useIfExists: true) {
            lines.append(terminated(dropStatement, databaseType: databaseType))
        }

        switch databaseType {
        case .microsoftSQL:
            if scriptDropAndCreate {
                lines.append(terminated(trimmedDefinition, databaseType: databaseType))
            } else if checkExistence {
                let typeCode = sqlServerTypeCode(for: object.type)
                lines.append("IF OBJECT_ID(N'\(sqlServerQualifiedName(object))', N'\(typeCode)') IS NULL")
                lines.append("BEGIN")
                lines.append(trimmedDefinition)
                lines.append("END")
                lines.append("GO")
            } else {
                lines.append(terminated(trimmedDefinition, databaseType: databaseType))
            }
        case .mysql, .postgresql, .sqlite:
            let normalizedDefinition = normalizedDefinition(
                trimmedDefinition,
                object: object,
                databaseType: databaseType,
                checkExistence: checkExistence && !scriptDropAndCreate
            )
            lines.append(terminated(normalizedDefinition, databaseType: databaseType))
        }

        return lines
            .joined(separator: databaseType == .microsoftSQL ? "\n" : "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func sqlServerTypeCode(for type: SchemaObjectInfo.ObjectType) -> String {
        switch type {
        case .table: return "U"
        case .view: return "V"
        case .procedure: return "P"
        case .function: return "FN"
        case .trigger: return "TR"
        case .synonym: return "SN"
        case .type: return "TT"
        case .sequence: return "SO"
        case .materializedView, .extension: return "U"
        }
    }

    private static func terminated(_ statement: String, databaseType: DatabaseType) -> String {
        let trimmed = statement.trimmingCharacters(in: .whitespacesAndNewlines)
        switch databaseType {
        case .microsoftSQL:
            if trimmed.hasSuffix("GO") {
                return trimmed
            }
            return trimmed + "\nGO"
        case .mysql, .postgresql, .sqlite:
            if trimmed.hasSuffix(";") {
                return trimmed
            }
            return trimmed + ";"
        }
    }

    private static func normalizedDefinition(
        _ definition: String,
        object: GenerateScriptsObject,
        databaseType: DatabaseType,
        checkExistence: Bool
    ) -> String {
        guard checkExistence else { return definition }

        switch databaseType {
        case .mysql:
            switch object.type {
            case .table:
                return replaceLeadingKeyword(in: definition, from: "CREATE TABLE", to: "CREATE TABLE IF NOT EXISTS")
            case .view:
                return replaceLeadingKeyword(in: definition, from: "CREATE VIEW", to: "CREATE OR REPLACE VIEW")
            case .procedure, .function, .trigger, .materializedView, .extension, .sequence, .type, .synonym:
                return definition
            }
        case .postgresql:
            switch object.type {
            case .table:
                return replaceLeadingKeyword(in: definition, from: "CREATE TABLE", to: "CREATE TABLE IF NOT EXISTS")
            case .view:
                return replaceLeadingKeyword(in: definition, from: "CREATE VIEW", to: "CREATE OR REPLACE VIEW")
            case .function:
                return replaceLeadingKeyword(in: definition, from: "CREATE FUNCTION", to: "CREATE OR REPLACE FUNCTION")
            case .procedure:
                return replaceLeadingKeyword(in: definition, from: "CREATE PROCEDURE", to: "CREATE OR REPLACE PROCEDURE")
            case .materializedView, .trigger, .extension, .sequence, .type, .synonym:
                return definition
            }
        case .sqlite:
            if object.type == .table {
                return replaceLeadingKeyword(in: definition, from: "CREATE TABLE", to: "CREATE TABLE IF NOT EXISTS")
            }
            return definition
        case .microsoftSQL:
            return definition
        }
    }

    private static func replaceLeadingKeyword(in definition: String, from source: String, to replacement: String) -> String {
        guard let range = definition.range(of: source, options: [.caseInsensitive, .anchored]) else {
            return definition
        }

        var updated = definition
        updated.replaceSubrange(range, with: replacement)
        return updated
    }

    private static func dropStatement(
        for object: GenerateScriptsObject,
        databaseType: DatabaseType,
        useIfExists: Bool
    ) -> String? {
        let keyword = dropKeyword(for: object.type)
        let target = qualifiedReference(for: object, databaseType: databaseType)

        switch databaseType {
        case .microsoftSQL:
            let existenceGuard = useIfExists ? "IF OBJECT_ID(N'\(sqlServerQualifiedName(object))', N'\(sqlServerTypeCode(for: object.type))') IS NOT NULL\n" : ""
            return "\(existenceGuard)DROP \(keyword) \(target)"
        case .mysql, .postgresql, .sqlite:
            let ifExists = useIfExists ? " IF EXISTS" : ""
            return "DROP \(keyword)\(ifExists) \(target)"
        }
    }

    private static func dropKeyword(for type: SchemaObjectInfo.ObjectType) -> String {
        switch type {
        case .table: return "TABLE"
        case .view: return "VIEW"
        case .materializedView: return "MATERIALIZED VIEW"
        case .function: return "FUNCTION"
        case .trigger: return "TRIGGER"
        case .procedure: return "PROCEDURE"
        case .extension: return "EXTENSION"
        case .sequence: return "SEQUENCE"
        case .type: return "TYPE"
        case .synonym: return "SYNONYM"
        }
    }

    private static func sqlServerQualifiedName(_ object: GenerateScriptsObject) -> String {
        if object.schema.isEmpty {
            return "[\(object.name.replacingOccurrences(of: "]", with: "]]"))]"
        }
        return "[\(object.schema.replacingOccurrences(of: "]", with: "]]"))].[\(object.name.replacingOccurrences(of: "]", with: "]]"))]"
    }
}
