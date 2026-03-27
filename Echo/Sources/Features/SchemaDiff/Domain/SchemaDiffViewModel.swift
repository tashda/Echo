import Foundation
import Observation
import PostgresKit

@Observable
final class SchemaDiffViewModel {

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

    var filteredDiffs: [SchemaDiffItem] {
        guard let filter = filterStatus else { return diffs }
        return diffs.filter { $0.status == filter }
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

    init(session: DatabaseSession, connectionID: UUID, connectionSessionID: UUID) {
        self.session = session
        self.connectionID = connectionID
        self.connectionSessionID = connectionSessionID
    }

    func setPanelState(_ state: BottomPanelState) {
        self.panelState = state
    }

    func initialize() async {
        guard let pg = session as? PostgresSession else { return }
        isInitialized = true
        do {
            availableSchemas = try await pg.client.introspection.listSchemas().map(\.name)
            if targetSchema.isEmpty, availableSchemas.count > 1 {
                targetSchema = availableSchemas.first { $0 != sourceSchema } ?? ""
            }
        } catch {
            panelState?.appendMessage("Failed to load schemas: \(error.localizedDescription)", severity: .error)
        }
    }

    func compare() async {
        guard canCompare, let pg = session as? PostgresSession else { return }
        isComparing = true
        diffs = []
        selectedDiffID = nil
        let handle = activityEngine?.begin("Schema Diff: \(sourceSchema) vs \(targetSchema)", connectionSessionID: connectionSessionID)

        do {
            let sourceObjects = try await pg.client.introspection.listTablesAndViews(schema: sourceSchema)
            let targetObjects = try await pg.client.introspection.listTablesAndViews(schema: targetSchema)

            let sourceByName = Dictionary(uniqueKeysWithValues: sourceObjects.map { ("\($0.kind.rawValue):\($0.name)", $0) })
            let targetByName = Dictionary(uniqueKeysWithValues: targetObjects.map { ("\($0.kind.rawValue):\($0.name)", $0) })

            var items: [SchemaDiffItem] = []

            // Objects in source but not in target (removed from target's perspective)
            for (key, obj) in sourceByName where targetByName[key] == nil {
                let ddl = await fetchDDL(pg: pg, schema: sourceSchema, object: obj)
                items.append(SchemaDiffItem(
                    objectType: obj.kind.rawValue,
                    objectName: obj.name,
                    status: .removed,
                    sourceDDL: ddl,
                    targetDDL: nil
                ))
            }

            // Objects in target but not in source (added)
            for (key, obj) in targetByName where sourceByName[key] == nil {
                let ddl = await fetchDDL(pg: pg, schema: targetSchema, object: obj)
                items.append(SchemaDiffItem(
                    objectType: obj.kind.rawValue,
                    objectName: obj.name,
                    status: .added,
                    sourceDDL: nil,
                    targetDDL: ddl
                ))
            }

            // Objects in both — compare DDL
            for (key, sourceObj) in sourceByName {
                guard let targetObj = targetByName[key] else { continue }
                let srcDDL = await fetchDDL(pg: pg, schema: sourceSchema, object: sourceObj)
                let tgtDDL = await fetchDDL(pg: pg, schema: targetSchema, object: targetObj)
                let status: SchemaDiffStatus = (srcDDL == tgtDDL) ? .identical : .modified
                items.append(SchemaDiffItem(
                    objectType: sourceObj.kind.rawValue,
                    objectName: sourceObj.name,
                    status: status,
                    sourceDDL: srcDDL,
                    targetDDL: tgtDDL
                ))
            }

            items.sort { $0.objectName.localizedCaseInsensitiveCompare($1.objectName) == .orderedAscending }
            diffs = items
            handle?.succeed()
        } catch {
            panelState?.appendMessage("Schema diff failed: \(error.localizedDescription)", severity: .error)
            handle?.fail(error.localizedDescription)
        }

        isComparing = false
    }

    func generateMigrationSQL(for item: SchemaDiffItem) -> String {
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

    // MARK: - Private

    private func fetchDDL(pg: PostgresSession, schema: String, object: SchemaObject) async -> String? {
        do {
            switch object.kind {
            case .view, .materializedView:
                return try await pg.client.introspection.viewDefinition(schema: schema, view: object.name)
            case .table:
                let columns = try await pg.client.introspection.listColumns(schema: schema, table: object.name)
                guard !columns.isEmpty else { return nil }
                let colDefs = columns.map { "\($0.name) \($0.dataType)\($0.isNullable ? "" : " NOT NULL")" }
                return "CREATE TABLE \(schema).\(object.name) (\n  " + colDefs.joined(separator: ",\n  ") + "\n);"
            }
        } catch {
            return nil
        }
    }
}
