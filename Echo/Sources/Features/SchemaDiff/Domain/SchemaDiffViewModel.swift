import Foundation
import Observation
import MySQLKit
import PostgresKit

@Observable
final class SchemaDiffViewModel {
    private struct DiffObject: Sendable {
        let kind: String
        let name: String
    }

    let connectionID: UUID
    let connectionSessionID: UUID
    @ObservationIgnored let session: DatabaseSession
    @ObservationIgnored var activityEngine: ActivityEngine?
    @ObservationIgnored private(set) var panelState: BottomPanelState?

    var availableSchemas: [String] = []
    var sourceSchema: String = "public"
    var targetSchema: String = ""
    var isComparing = false
    var isInitialized = false
    var diffs: [SchemaDiffItem] = []
    var selectedDiffID: SchemaDiffItem.ID?
    var filterStatus: SchemaDiffStatus?
    var filterObjectType: String?
    var searchText = ""

    var filteredDiffs: [SchemaDiffItem] {
        diffs.filter { item in
            let matchesStatus = filterStatus.map { item.status == $0 } ?? true
            let matchesType = filterObjectType.map { item.objectType.caseInsensitiveCompare($0) == .orderedSame } ?? true
            let matchesSearch: Bool
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                matchesSearch = true
            } else {
                let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                matchesSearch =
                    item.objectName.localizedCaseInsensitiveContains(needle) ||
                    item.objectType.localizedCaseInsensitiveContains(needle)
            }
            return matchesStatus && matchesType && matchesSearch
        }
    }

    var selectedDiff: SchemaDiffItem? {
        diffs.first { $0.id == selectedDiffID }
    }

    var statusSummary: String {
        let added = diffs.filter { $0.status == .added }.count
        let removed = diffs.filter { $0.status == .removed }.count
        let modified = diffs.filter { $0.status == .modified }.count
        let identical = diffs.filter { $0.status == .identical }.count
        return "+\(added)  -\(removed)  ~\(modified)  =\(identical)"
    }

    var canCompare: Bool {
        !sourceSchema.isEmpty && !targetSchema.isEmpty
            && sourceSchema != targetSchema && !isComparing
    }

    var availableObjectTypes: [String] {
        Array(Set(diffs.map(\.objectType))).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    init(session: DatabaseSession, connectionID: UUID, connectionSessionID: UUID) {
        self.session = session
        self.connectionID = connectionID
        self.connectionSessionID = connectionSessionID
    }

    func setPanelState(_ state: BottomPanelState) {
        panelState = state
    }

    func initialize() async {
        isInitialized = true

        do {
            switch session {
            case let pg as PostgresSession:
                availableSchemas = try await pg.client.introspection.listSchemas().map(\.name)
                if sourceSchema.isEmpty {
                    sourceSchema = availableSchemas.first ?? "public"
                }
            case let mysql as MySQLSession:
                availableSchemas = try await mysql.listDatabases().sorted()
                if sourceSchema == "public" || sourceSchema.isEmpty {
                    let currentDatabase = try await mysql.currentDatabaseName()
                    sourceSchema = availableSchemas.first ?? currentDatabase ?? ""
                }
            default:
                availableSchemas = []
            }

            if targetSchema.isEmpty, availableSchemas.count > 1 {
                targetSchema = availableSchemas.first { $0 != sourceSchema } ?? ""
            }
        } catch {
            panelState?.appendMessage("Failed to load schemas: \(error.localizedDescription)", severity: .error)
        }
    }

    func compare() async {
        guard canCompare else { return }

        isComparing = true
        diffs = []
        selectedDiffID = nil
        let handle = activityEngine?.begin("Schema Diff: \(sourceSchema) vs \(targetSchema)", connectionSessionID: connectionSessionID)

        do {
            switch session {
            case let pg as PostgresSession:
                diffs = try await comparePostgres(pg)
            case let mysql as MySQLSession:
                diffs = try await compareMySQL(mysql)
            default:
                diffs = []
            }
            handle?.succeed()
        } catch {
            panelState?.appendMessage("Schema diff failed: \(error.localizedDescription)", severity: .error)
            handle?.fail(error.localizedDescription)
        }

        isComparing = false
    }

    func generateMigrationSQL(for item: SchemaDiffItem) -> String {
        if session is MySQLSession {
            return generateMySQLMigrationSQL(for: item)
        }
        return generatePostgresMigrationSQL(for: item)
    }

    func generateMigrationSQLForFilteredDiffs() -> String {
        filteredDiffs
            .filter { $0.status != .identical }
            .map { generateMigrationSQL(for: $0) }
            .joined(separator: "\n\n")
    }

    private func comparePostgres(_ pg: PostgresSession) async throws -> [SchemaDiffItem] {
        let sourceObjects = try await pg.client.introspection.listTablesAndViews(schema: sourceSchema).map {
            DiffObject(kind: $0.kind.rawValue, name: $0.name)
        }
        let targetObjects = try await pg.client.introspection.listTablesAndViews(schema: targetSchema).map {
            DiffObject(kind: $0.kind.rawValue, name: $0.name)
        }

        return await buildDiffItems(
            sourceObjects: sourceObjects,
            targetObjects: targetObjects,
            sourceDDL: { object in await self.fetchPostgresDDL(pg: pg, schema: self.sourceSchema, object: object) },
            targetDDL: { object in await self.fetchPostgresDDL(pg: pg, schema: self.targetSchema, object: object) }
        )
    }

    private func compareMySQL(_ mysql: MySQLSession) async throws -> [SchemaDiffItem] {
        let sourceObjects = try await mysqlObjects(in: sourceSchema, mysql: mysql)
        let targetObjects = try await mysqlObjects(in: targetSchema, mysql: mysql)

        return await buildDiffItems(
            sourceObjects: sourceObjects,
            targetObjects: targetObjects,
            sourceDDL: { object in await self.fetchMySQLDDL(mysql: mysql, schema: self.sourceSchema, object: object) },
            targetDDL: { object in await self.fetchMySQLDDL(mysql: mysql, schema: self.targetSchema, object: object) }
        )
    }

    private func buildDiffItems(
        sourceObjects: [DiffObject],
        targetObjects: [DiffObject],
        sourceDDL: @escaping (DiffObject) async -> String?,
        targetDDL: @escaping (DiffObject) async -> String?
    ) async -> [SchemaDiffItem] {
        let sourceByName = Dictionary(uniqueKeysWithValues: sourceObjects.map { ("\($0.kind):\($0.name)", $0) })
        let targetByName = Dictionary(uniqueKeysWithValues: targetObjects.map { ("\($0.kind):\($0.name)", $0) })

        var items: [SchemaDiffItem] = []

        for (key, obj) in sourceByName where targetByName[key] == nil {
            let ddl = await sourceDDL(obj)
            items.append(
                SchemaDiffItem(
                    objectType: obj.kind,
                    objectName: obj.name,
                    status: .removed,
                    sourceDDL: ddl,
                    targetDDL: nil
                )
            )
        }

        for (key, obj) in targetByName where sourceByName[key] == nil {
            let ddl = await targetDDL(obj)
            items.append(
                SchemaDiffItem(
                    objectType: obj.kind,
                    objectName: obj.name,
                    status: .added,
                    sourceDDL: nil,
                    targetDDL: ddl
                )
            )
        }

        for (key, sourceObj) in sourceByName {
            guard let targetObj = targetByName[key] else { continue }
            let srcDDL = await sourceDDL(sourceObj)
            let tgtDDL = await targetDDL(targetObj)
            let normalizedSource = normalizeDDL(srcDDL, schema: sourceSchema)
            let normalizedTarget = normalizeDDL(tgtDDL, schema: targetSchema)
            let status: SchemaDiffStatus = (normalizedSource == normalizedTarget) ? .identical : .modified

            items.append(
                SchemaDiffItem(
                    objectType: sourceObj.kind,
                    objectName: sourceObj.name,
                    status: status,
                    sourceDDL: srcDDL,
                    targetDDL: tgtDDL
                )
            )
        }

        return items.sorted {
            if $0.objectType == $1.objectType {
                return $0.objectName.localizedCaseInsensitiveCompare($1.objectName) == .orderedAscending
            }
            return $0.objectType.localizedCaseInsensitiveCompare($1.objectType) == .orderedAscending
        }
    }

    private func fetchPostgresDDL(pg: PostgresSession, schema: String, object: DiffObject) async -> String? {
        do {
            switch object.kind {
            case SchemaObjectKind.view.rawValue, SchemaObjectKind.materializedView.rawValue:
                return try await pg.client.introspection.viewDefinition(schema: schema, view: object.name)
            case SchemaObjectKind.table.rawValue:
                let columns = try await pg.client.introspection.listColumns(schema: schema, table: object.name)
                guard !columns.isEmpty else { return nil }
                let colDefs = columns.map { "\($0.name) \($0.dataType)\($0.isNullable ? "" : " NOT NULL")" }
                return "CREATE TABLE \(schema).\(object.name) (\n  " + colDefs.joined(separator: ",\n  ") + "\n);"
            default:
                return nil
            }
        } catch {
            return nil
        }
    }

    private func mysqlObjects(in schema: String, mysql: MySQLSession) async throws -> [DiffObject] {
        let schemaObjects = try await mysql.client.metadata.listTablesAndViews(in: schema).map {
            DiffObject(kind: $0.kind.rawValue, name: $0.name)
        }
        let routines = try await mysql.client.metadata.listRoutines(in: schema).map {
            DiffObject(kind: $0.type.lowercased(), name: $0.name)
        }
        let triggers = try await mysql.client.metadata.listTriggers(in: schema).map {
            DiffObject(kind: "trigger", name: $0.name)
        }
        let events = try await mysql.client.metadata.listEvents(in: schema).map {
            DiffObject(kind: "event", name: $0.name)
        }

        return schemaObjects + routines + triggers + events
    }

    private func fetchMySQLDDL(mysql: MySQLSession, schema: String, object: DiffObject) async -> String? {
        do {
            guard let kind = MySQLSchemaObjectKind(rawValue: object.kind.lowercased()) else {
                return nil
            }
            return try await mysql.client.metadata.objectDefinition(named: object.name, schema: schema, kind: kind)
        } catch {
            return nil
        }
    }

    private func normalizeDDL(_ ddl: String?, schema: String) -> String? {
        guard var ddl else { return nil }

        let normalizedSchema = schema.replacingOccurrences(of: "\"", with: "\"\"")
        ddl = ddl.replacingOccurrences(of: "\"\(normalizedSchema)\".", with: "\"<schema>\".")

        let mysqlSchema = schema.replacingOccurrences(of: "`", with: "``")
        ddl = ddl.replacingOccurrences(of: "`\(mysqlSchema)`.", with: "`<schema>`.")
        ddl = ddl.replacingOccurrences(of: "DEFINER=`root`@`localhost` ", with: "")
        ddl = ddl.replacingOccurrences(of: "DEFINER=`<schema>`@`localhost` ", with: "")

        return ddl.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func generatePostgresMigrationSQL(for item: SchemaDiffItem) -> String {
        switch item.status {
        case .added:
            return item.targetDDL ?? "-- No DDL available for \(item.objectName)"
        case .removed:
            return "DROP \(item.objectType.uppercased()) IF EXISTS \(sourceSchema).\(item.objectName) CASCADE;"
        case .modified:
            var sql = "-- Modified: \(item.objectName)\n"
            sql += "-- Source schema: \(sourceSchema)\n"
            sql += "-- Target schema: \(targetSchema)\n\n"
            if let tgtDDL = item.targetDDL {
                sql += "-- Target definition:\n\(tgtDDL)\n"
            }
            return sql
        case .identical:
            return "-- No changes needed for \(item.objectName)"
        }
    }

    private func generateMySQLMigrationSQL(for item: SchemaDiffItem) -> String {
        let dropStatement = mysqlDropStatement(for: item)

        switch item.status {
        case .added:
            return item.targetDDL ?? "-- No DDL available for \(item.objectName)"
        case .removed:
            return dropStatement
        case .modified:
            if let targetDDL = item.targetDDL {
                if shouldDropBeforeCreate(objectType: item.objectType) {
                    return "\(dropStatement)\n\n\(targetDDL)"
                }
                return targetDDL
            }
            return "-- No target definition available for \(item.objectName)"
        case .identical:
            return "-- No changes needed for \(item.objectName)"
        }
    }

    private func mysqlDropStatement(for item: SchemaDiffItem) -> String {
        let escapedSchema = sourceSchema.replacingOccurrences(of: "`", with: "``")
        let escapedName = item.objectName.replacingOccurrences(of: "`", with: "``")

        switch item.objectType.lowercased() {
        case "table":
            return "DROP TABLE IF EXISTS `\(escapedSchema)`.`\(escapedName)`;"
        case "view":
            return "DROP VIEW IF EXISTS `\(escapedSchema)`.`\(escapedName)`;"
        case "function":
            return "DROP FUNCTION IF EXISTS `\(escapedName)`;"
        case "procedure":
            return "DROP PROCEDURE IF EXISTS `\(escapedName)`;"
        case "trigger":
            return "DROP TRIGGER IF EXISTS `\(escapedSchema)`.`\(escapedName)`;"
        case "event":
            return "DROP EVENT IF EXISTS `\(escapedSchema)`.`\(escapedName)`;"
        default:
            return "-- Drop not available for \(item.objectType) \(item.objectName)"
        }
    }

    private func shouldDropBeforeCreate(objectType: String) -> Bool {
        switch objectType.lowercased() {
        case "function", "procedure", "trigger", "event", "view":
            return true
        default:
            return false
        }
    }
}
