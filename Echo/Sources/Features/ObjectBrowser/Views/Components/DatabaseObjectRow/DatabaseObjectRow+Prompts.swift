import SwiftUI

extension DatabaseObjectRow {
    internal func performDrop(includeIfExists: Bool) {
        guard let session = environmentState.sessionGroup.sessionForConnection(connection.id) else { return }
        let objectName = object.fullName
        connectionStore.selectedConnectionID = session.connection.id

        Task {
            do {
                let targetSession = try await databaseScopedSession(session)
                if object.type == .table {
                    let schema = object.schema.isEmpty ? nil : object.schema
                    try await targetSession.dropTable(schema: schema, name: object.name, ifExists: includeIfExists)
                } else {
                    let statement = dropStatement(includeIfExists: includeIfExists)
                    _ = try await targetSession.executeUpdate(statement)
                }
                if isPinned {
                    await MainActor.run { onTogglePin() }
                }
                await MainActor.run {
                    removeObjectFromStructure(session: session)
                    environmentState.notificationEngine?.post(category: .objectDropped, message: "Dropped \(objectName)")
                }
                await environmentState.refreshDatabaseStructure(
                    for: session.id,
                    scope: .selectedDatabase,
                    databaseOverride: session.sidebarFocusedDatabase
                )
            } catch {
                await MainActor.run {
                    environmentState.lastError = DatabaseError.from(error)
                    ConnectionDebug.log("[Drop] Failed to drop \(objectName): \(error)")
                    environmentState.notificationEngine?.post(category: .generalError, message: "Failed to drop \(objectName): \(error.localizedDescription)")
                }
            }
        }
    }

    internal func performRename() {
        guard let session = environmentState.sessionGroup.sessionForConnection(connection.id) else { return }
        let newName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != object.name else { return }
        let objectName = object.fullName
        connectionStore.selectedConnectionID = session.connection.id

        Task {
            do {
                let targetSession = try await databaseScopedSession(session)
                if object.type == .table {
                    let schema = object.schema.isEmpty ? nil : object.schema
                    try await targetSession.renameTable(schema: schema, oldName: object.name, newName: newName)
                } else if let sql = renameStatement(newName: newName) {
                    _ = try await targetSession.executeUpdate(sql)
                } else {
                    if let template = renameStatement() {
                        await MainActor.run { openScriptTab(with: template) }
                    }
                    return
                }
                await MainActor.run {
                    renameObjectInStructure(session: session, newName: newName)
                    environmentState.notificationEngine?.post(category: .objectRenamed, message: "Renamed \(objectName) to \(newName)")
                }
                await environmentState.refreshDatabaseStructure(
                    for: session.id,
                    scope: .selectedDatabase,
                    databaseOverride: session.sidebarFocusedDatabase
                )
            } catch {
                await MainActor.run {
                    let dbError = DatabaseError.from(error)
                    environmentState.lastError = dbError
                    ConnectionDebug.log("[Rename] Failed to rename \(objectName): \(error)")
                    environmentState.notificationEngine?.post(category: .generalError, message: "Failed to rename \(objectName): \(error.localizedDescription)")
                }
            }
        }
    }

    internal func performTruncate() {
        guard let session = environmentState.sessionGroup.sessionForConnection(connection.id) else { return }
        let objectName = object.fullName
        connectionStore.selectedConnectionID = session.connection.id

        Task {
            do {
                let targetSession = try await databaseScopedSession(session)
                if object.type == .table {
                    let schema = object.schema.isEmpty ? nil : object.schema
                    try await targetSession.truncateTable(schema: schema, name: object.name)
                } else {
                    let statement = truncateStatement()
                    _ = try await targetSession.executeUpdate(statement)
                }
                await MainActor.run {
                    environmentState.notificationEngine?.post(category: .objectTruncated, message: "Truncated \(objectName)")
                }
            } catch {
                await MainActor.run {
                    environmentState.lastError = DatabaseError.from(error)
                    ConnectionDebug.log("[Truncate] Failed to truncate \(objectName): \(error)")
                    environmentState.notificationEngine?.post(category: .generalError, message: "Failed to truncate \(objectName): \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Database Context

    /// Returns a session scoped to the correct database.
    /// For MSSQL this issues USE [database] to switch context; for Postgres it returns a connection to the right database.
    private func databaseScopedSession(_ session: ConnectionSession) async throws -> DatabaseSession {
        if let dbName = databaseName, !dbName.isEmpty {
            return try await session.session.sessionForDatabase(dbName)
        }
        return session.session
    }

    // MARK: - Optimistic Local Updates

    @MainActor
    private func removeObjectFromStructure(session: ConnectionSession) {
        guard var structure = session.databaseStructure,
              let dbName = databaseName,
              let dbIndex = structure.databases.firstIndex(where: { $0.name == dbName }) else { return }

        var db = structure.databases[dbIndex]
        let schemaName = object.schema
        guard let schemaIndex = db.schemas.firstIndex(where: { $0.name == schemaName }) else { return }

        let schema = db.schemas[schemaIndex]
        let filtered = schema.objects.filter { $0.id != object.id }
        db.schemas[schemaIndex] = SchemaInfo(name: schemaName, objects: filtered)
        structure.databases[dbIndex] = db
        session.databaseStructure = structure
    }

    @MainActor
    private func renameObjectInStructure(session: ConnectionSession, newName: String) {
        guard var structure = session.databaseStructure,
              let dbName = databaseName,
              let dbIndex = structure.databases.firstIndex(where: { $0.name == dbName }) else { return }

        var db = structure.databases[dbIndex]
        let schemaName = object.schema
        guard let schemaIndex = db.schemas.firstIndex(where: { $0.name == schemaName }) else { return }

        let schema = db.schemas[schemaIndex]
        let updated = schema.objects.map { obj -> SchemaObjectInfo in
            guard obj.id == object.id else { return obj }
            return SchemaObjectInfo(
                name: newName,
                schema: obj.schema,
                type: obj.type,
                columns: obj.columns,
                parameters: obj.parameters,
                triggerAction: obj.triggerAction,
                triggerTable: obj.triggerTable,
                comment: obj.comment
            )
        }
        let sorted = updated.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        db.schemas[schemaIndex] = SchemaInfo(name: schemaName, objects: sorted)
        structure.databases[dbIndex] = db
        session.databaseStructure = structure
    }
}
