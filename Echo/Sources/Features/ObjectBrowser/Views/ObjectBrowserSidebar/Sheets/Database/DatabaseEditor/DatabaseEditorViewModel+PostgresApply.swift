import Foundation
import PostgresKit

// MARK: - PostgreSQL Apply & Save Operations

extension DatabaseEditorViewModel {

    // MARK: - Apply Alter

    func applyPgAlter(
        session: ConnectionSession,
        message: String = "Database properties updated.",
        _ action: (PostgresKit.PostgresClient) async throws -> Void
    ) async {
        guard let pgSession = session.session as? PostgresSession else { return }
        let client = pgSession.client
        isSaving = true
        statusMessage = nil

        do {
            try await action(client)
            isSaving = false
            notificationEngine?.post(category: .databasePropertiesSaved, message: message)
            await environmentState?.refreshDatabaseStructure(for: session.id)
        } catch {
            isSaving = false
            statusMessage = error.localizedDescription
            notificationEngine?.post(category: .databasePropertiesError, message: error.localizedDescription)
        }
    }

    // MARK: - Save Parameter Changes

    func pgSaveParameterChanges(session: ConnectionSession) async {
        let originalNames = Set(pgOriginalParams.map(\.name))
        let currentNames = Set(pgParams.map(\.name))
        let originalMap = Dictionary(pgOriginalParams.map { ($0.name, $0.value) }, uniquingKeysWith: { _, b in b })

        let removed = originalNames.subtracting(currentNames)
        var upserted: [(name: String, value: String)] = []
        for param in pgParams {
            if let oldValue = originalMap[param.name] {
                if oldValue != param.value { upserted.append((param.name, param.value)) }
            } else {
                upserted.append((param.name, param.value))
            }
        }

        guard !removed.isEmpty || !upserted.isEmpty else { return }

        let removedList = Array(removed)
        let upsertedList = upserted
        let changeCount = removedList.count + upsertedList.count

        guard let pgSession = session.session as? PostgresSession else { return }
        let client = pgSession.client
        isSaving = true

        do {
            for name in removedList {
                try await client.admin.alterDatabaseReset(name: databaseName, parameter: name)
            }
            for param in upsertedList {
                try await client.admin.alterDatabaseSet(name: databaseName, parameter: param.name, value: param.value)
            }
            isSaving = false
            notificationEngine?.post(
                category: .databasePropertiesSaved,
                message: "\(changeCount) parameter\(changeCount == 1 ? "" : "s") updated on \(databaseName)."
            )
            await environmentState?.refreshDatabaseStructure(for: session.id)
        } catch {
            isSaving = false
            notificationEngine?.post(
                category: .databasePropertiesError,
                message: error.localizedDescription
            )
        }

        pgOriginalParams = pgParams
    }

    // MARK: - Save Default Privilege Changes

    func pgSaveDefaultPrivilegeChanges(session: ConnectionSession) async {
        typealias Key = String // "schema:objType:grantee"
        func makeKey(_ e: PostgresDefaultPrivilege) -> Key {
            "\(e.schema):\(e.objectType.rawValue):\(e.grantee)"
        }

        let originalByKey = Dictionary(pgOriginalDefaultPrivileges.map { (makeKey($0), $0) }, uniquingKeysWith: { _, b in b })
        let currentByKey = Dictionary(pgDefaultPrivileges.map { (makeKey($0), $0) }, uniquingKeysWith: { _, b in b })

        let originalKeys = Set(originalByKey.keys)
        let currentKeys = Set(currentByKey.keys)

        let removedKeys = originalKeys.subtracting(currentKeys)
        let addedKeys = currentKeys.subtracting(originalKeys)
        let commonKeys = originalKeys.intersection(currentKeys)

        var changeCount = 0
        var grantOps: [(schema: String, privs: [PostgresPrivilege], objType: PostgresObjectType, to: String, withGrant: Bool)] = []
        var revokeOps: [(schema: String, privs: [PostgresPrivilege], objType: PostgresObjectType, from: String)] = []

        for key in removedKeys {
            if let orig = originalByKey[key] {
                let schema = orig.schema.isEmpty ? "public" : orig.schema
                let grantee = orig.grantee.isEmpty ? "PUBLIC" : orig.grantee
                revokeOps.append((schema, orig.privileges.map(\.privilege), orig.objectType, grantee))
                changeCount += 1
            }
        }

        for key in addedKeys {
            if let cur = currentByKey[key] {
                let schema = cur.schema.isEmpty ? "public" : cur.schema
                let grantee = cur.grantee.isEmpty ? "PUBLIC" : cur.grantee
                grantOps.append((schema, cur.privileges.map(\.privilege), cur.objectType, grantee, false))
                changeCount += 1
            }
        }

        for key in commonKeys {
            guard let orig = originalByKey[key], let cur = currentByKey[key] else { continue }
            let origPrivs = Set(orig.privileges.map(\.privilege))
            let curPrivs = Set(cur.privileges.map(\.privilege))
            let schema = cur.schema.isEmpty ? "public" : cur.schema
            let grantee = cur.grantee.isEmpty ? "PUBLIC" : cur.grantee

            let added = curPrivs.subtracting(origPrivs)
            let removed = origPrivs.subtracting(curPrivs)

            if !added.isEmpty {
                grantOps.append((schema, Array(added), cur.objectType, grantee, false))
                changeCount += 1
            }
            if !removed.isEmpty {
                revokeOps.append((schema, Array(removed), cur.objectType, grantee))
                changeCount += 1
            }
        }

        guard changeCount > 0 else { return }

        let revokeList = revokeOps
        let grantList = grantOps

        await applyPgAlter(session: session, message: "Default privileges updated (\(changeCount) change\(changeCount == 1 ? "" : "s")).") { client in
            for op in revokeList {
                try await client.security.revokeDefaultPrivileges(
                    schema: op.schema, revoke: op.privs, onObjectType: op.objType, from: op.from
                )
            }
            for op in grantList {
                try await client.security.alterDefaultPrivileges(
                    schema: op.schema, grant: op.privs, onObjectType: op.objType, to: op.to
                )
            }
        }

        pgOriginalDefaultPrivileges = pgDefaultPrivileges
    }

    // MARK: - SQL Generation

    func pgGenerateFullSQL() -> String {
        var statements: [String] = []
        let db = pgQuoteIdent(databaseName)

        for param in pgParams {
            statements.append("ALTER DATABASE \(db) SET \(param.name) = '\(pgEscape(param.value))';")
        }

        for entry in pgACLEntries {
            let grantee = entry.grantee.isEmpty ? "PUBLIC" : pgQuoteIdent(entry.grantee)
            let privs = entry.privileges.map(\.privilege.rawValue).joined(separator: ", ")
            if !privs.isEmpty {
                statements.append("GRANT \(privs) ON DATABASE \(db) TO \(grantee);")
            }
        }

        for entry in pgDefaultPrivileges {
            let schema = entry.schema.isEmpty ? "public" : entry.schema
            let grantee = entry.grantee.isEmpty ? "PUBLIC" : pgQuoteIdent(entry.grantee)
            let privs = entry.privileges.map(\.privilege.rawValue).joined(separator: ", ")
            if !privs.isEmpty {
                statements.append("ALTER DEFAULT PRIVILEGES IN SCHEMA \(pgQuoteIdent(schema)) GRANT \(privs) ON \(entry.objectType.rawValue) TO \(grantee);")
            }
        }

        return statements.joined(separator: "\n\n")
    }

    // MARK: - Computed Helpers

    var pgAvailableParameters: [PostgresSettingDefinition] {
        let existing = Set(pgParams.map(\.name))
        return pgSettingDefinitions.filter { !existing.contains($0.name) }
    }

    func pgSettingDefinition(for name: String) -> PostgresSettingDefinition? {
        pgSettingDefinitions.first(where: { $0.name == name })
    }

    func pgAddParameterWithDefault(name: String) {
        guard let def = pgSettingDefinition(for: name) else { return }
        let defaultValue: String
        switch def.vartype {
        case "bool": defaultValue = def.bootVal.isEmpty ? "off" : def.bootVal
        case "enum": defaultValue = def.enumVals.first ?? def.bootVal
        default: defaultValue = def.bootVal
        }
        pgParams.append(PostgresDatabaseParameter(name: name, value: defaultValue))
    }

    // MARK: - Private Helpers

    private func pgQuoteIdent(_ name: String) -> String {
        "\"\(name.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private func pgEscape(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }
}
