import Foundation

struct DatabaseStructureFetcher {
    struct Credentials {
        let username: String
        let password: String?
    }

    struct Progress {
        let fraction: Double
        let databaseName: String
        let schemaName: String?
        let message: String?
    }

    let factory: DatabaseFactory

    func fetchStructure(
        for connection: SavedConnection,
        credentials: Credentials,
        selectedDatabase: String?,
        reuseSession: DatabaseSession? = nil,
        databaseFilter: [String]? = nil,
        progressHandler: (@Sendable (Progress) async -> Void)? = nil,
        databaseHandler: (@Sendable (DatabaseInfo, Int, Int) async -> Void)? = nil
    ) async throws -> DatabaseStructure {
        let progressCallback = progressHandler

        func emitProgress(
            _ fraction: Double,
            databaseName: String,
            schemaName: String?,
            message: String?
        ) async {
            guard let progressCallback else { return }
            let clamped = min(max(fraction, 0), 1)
            await progressCallback(Progress(fraction: clamped, databaseName: databaseName, schemaName: schemaName, message: message))
        }

        func message(for type: SchemaObjectInfo.ObjectType) -> String {
            switch type {
            case .table:
                return "Updating tables…"
            case .view:
                return "Updating views…"
            case .materializedView:
                return "Updating materialized views…"
            case .function:
                return "Updating functions…"
            case .trigger:
                return "Updating triggers…"
            }
        }

        let baseSession: DatabaseSession
        if let reuseSession {
            baseSession = reuseSession
        } else {
            baseSession = try await factory.connect(
                host: connection.host,
                port: connection.port,
                username: credentials.username,
                password: credentials.password,
                database: connection.database.isEmpty ? nil : connection.database,
                tls: connection.useTLS
            )
        }

        defer {
            if reuseSession == nil {
                Task { await baseSession.close() }
            }
        }

        var serverVersion = connection.serverVersion
        if serverVersion == nil {
            if let result = try? await baseSession.simpleQuery("SHOW server_version"),
               let rawValue = result.rows.first?.first,
               let version = rawValue,
               !version.isEmpty {
                serverVersion = version
            } else if let fallback = try? await baseSession.simpleQuery("SELECT version()"),
                      let rawValue = fallback.rows.first?.first,
                      let version = rawValue,
                      !version.isEmpty {
                serverVersion = version
            }
        }

        var baseSessionDatabaseName: String?
        if let currentDatabase = try? await baseSession.simpleQuery("SELECT current_database()"),
           let rawValue = currentDatabase.rows.first?.first,
           let databaseName = rawValue,
           !databaseName.isEmpty {
            baseSessionDatabaseName = databaseName
        }

        var databaseNames: [String]
        if let databaseFilter, !databaseFilter.isEmpty {
            var unique: [String] = []
            for name in databaseFilter where !name.isEmpty {
                if !unique.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                    unique.append(name)
                }
            }
            databaseNames = unique.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        } else {
            var fetched = try await baseSession.listDatabases()
            let explicitDatabase = connection.database
            if !explicitDatabase.isEmpty && !fetched.contains(explicitDatabase) {
                fetched.append(explicitDatabase)
            }
            databaseNames = Array(Set(fetched)).sorted()
            if databaseNames.isEmpty && !explicitDatabase.isEmpty {
                databaseNames = [explicitDatabase]
            }
        }

        let totalDatabases = max(databaseNames.count, 1)
        var databaseInfos: [DatabaseInfo] = []

        for (databaseIndex, databaseName) in databaseNames.enumerated() {
            let databaseStartFraction = Double(databaseIndex) / Double(totalDatabases)
            await emitProgress(databaseStartFraction, databaseName: databaseName, schemaName: nil, message: "Updating database \(databaseName)…")

            var sessionForDatabase: DatabaseSession?
            var shouldCloseSession = false
            var connectionError: Error?

            if let reuseSession,
               let selectedDatabase,
               databaseName == selectedDatabase {
                sessionForDatabase = reuseSession
            } else if reuseSession == nil,
                      let baseDatabaseName = baseSessionDatabaseName,
                      databaseName == baseDatabaseName {
                sessionForDatabase = baseSession
            } else {
                do {
                    sessionForDatabase = try await factory.connect(
                        host: connection.host,
                        port: connection.port,
                        username: credentials.username,
                        password: credentials.password,
                        database: databaseName,
                        tls: connection.useTLS
                    )
                    shouldCloseSession = (sessionForDatabase != nil)
                } catch {
                    connectionError = error
                }
            }

            guard let activeSession = sessionForDatabase else {
                if let error = connectionError {
                    print("Failed to connect to database \(databaseName) for connection \(connection.connectionName): \(error.localizedDescription)")
                }
                let placeholder = DatabaseInfo(name: databaseName, schemas: [], schemaCount: 0)
                databaseInfos.append(placeholder)
                if let databaseHandler {
                    await databaseHandler(placeholder, databaseIndex, totalDatabases)
                }
                let completionFraction = Double(databaseIndex + 1) / Double(totalDatabases)
                await emitProgress(completionFraction, databaseName: databaseName, schemaName: nil, message: "Database \(databaseName) skipped")
                continue
            }

            let sessionToClose: DatabaseSession? = shouldCloseSession ? activeSession : nil
            defer {
                if let sessionToClose {
                    Task { await sessionToClose.close() }
                }
            }

            do {
                let schemaNames = try await activeSession.listSchemas()
                var schemas: [SchemaInfo] = []
                let totalSchemas = max(schemaNames.count, 1)

                if schemaNames.isEmpty {
                    let completionFraction = Double(databaseIndex + 1) / Double(totalDatabases)
                    await emitProgress(completionFraction, databaseName: databaseName, schemaName: nil, message: "No schemas found")
                }

                for (schemaIndex, schemaName) in schemaNames.enumerated() {
                    let schemaBaseFraction = (
                        Double(databaseIndex)
                        + Double(schemaIndex) / Double(totalSchemas)
                    ) / Double(totalDatabases)
                    await emitProgress(schemaBaseFraction, databaseName: databaseName, schemaName: schemaName, message: "Updating schema \(schemaName)…")

                    let schemaInfo: SchemaInfo
                    if let metadataSession = activeSession as? DatabaseMetadataSession {
                        schemaInfo = try await metadataSession.loadSchemaInfo(schemaName) { objectType, currentIndex, total in
                            let normalizedTotal = max(total, 1)
                            let objectFraction = Double(currentIndex) / Double(normalizedTotal)
                            let schemaFraction = (
                                Double(schemaIndex) + objectFraction
                            ) / Double(totalSchemas)
                            let overallFraction = (
                                Double(databaseIndex) + schemaFraction
                            ) / Double(totalDatabases)
                            await emitProgress(overallFraction, databaseName: databaseName, schemaName: schemaName, message: message(for: objectType))
                        }
                    } else {
                        let objects = try await activeSession.listTablesAndViews(schema: schemaName)
                        schemaInfo = SchemaInfo(name: schemaName, objects: objects)
                    }

                    schemas.append(schemaInfo)

                    let schemaCompletionFraction = (
                        Double(databaseIndex)
                        + Double(schemaIndex + 1) / Double(totalSchemas)
                    ) / Double(totalDatabases)
                    await emitProgress(schemaCompletionFraction, databaseName: databaseName, schemaName: schemaName, message: "Schema \(schemaName) updated")
                }

                let info = DatabaseInfo(name: databaseName, schemas: schemas, schemaCount: schemas.count)
                databaseInfos.append(info)
                if let databaseHandler {
                    await databaseHandler(info, databaseIndex, totalDatabases)
                }
            } catch {
                print("Failed to load metadata for database \(databaseName) on connection \(connection.connectionName): \(error.localizedDescription)")
                let info = DatabaseInfo(name: databaseName, schemas: [], schemaCount: 0)
                databaseInfos.append(info)
                if let databaseHandler {
                    await databaseHandler(info, databaseIndex, totalDatabases)
                }
            }

            let databaseCompletionFraction = Double(databaseIndex + 1) / Double(totalDatabases)
            await emitProgress(databaseCompletionFraction, databaseName: databaseName, schemaName: nil, message: "Database \(databaseName) updated")
        }

        let structure = DatabaseStructure(
            serverVersion: serverVersion,
            databases: databaseInfos.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        )

        await emitProgress(1.0, databaseName: "", schemaName: nil, message: "Metadata cached")

        return structure
    }
}
