import EchoSense
import Foundation
import Observation
import PostgresKit
import SQLServerKit

/// One live connection to a test server, through the real driver packages.
@Observable @MainActor
final class LabLiveConnection {
    enum State: Equatable {
        case idle, connecting, connected
        case failed(String)
    }

    struct QueryOutput {
        var columns: [String]
        var rows: [[String]]
        var elapsed: Duration
    }

    let profile: LabConnectionProfile
    private(set) var state: State = .idle
    private(set) var serverVersion: String?
    private(set) var databases: [String] = []
    private(set) var structure: EchoSenseDatabaseStructure?
    private(set) var log: [String] = []

    private var mssql: SQLServerClient?
    private var postgres: PostgresClient?

    init(profile: LabConnectionProfile) { self.profile = profile }

    var dialect: EchoSenseDatabaseType { profile.isSQLServer ? .microsoftSQL : .postgresql }

    // MARK: Connection

    func connect() async {
        guard state != .connecting else { return }
        state = .connecting
        note("Connecting to \(profile.host):\(profile.port.map(String.init) ?? "default")")
        let start = ContinuousClock.now
        do {
            if profile.isSQLServer {
                let client = try await SQLServerClient.connect(configuration: SQLServerClient.Configuration(
                    hostname: profile.host,
                    port: profile.port ?? 1433,
                    database: profile.database.flatMap { $0.isEmpty ? nil : $0 } ?? "master",
                    authentication: .sqlPassword(username: profile.username ?? "sa", password: profile.password ?? ""),
                    tlsEnabled: profile.useTLS ?? false,
                    trustServerCertificate: profile.trustServerCertificate ?? true))
                mssql = client
                serverVersion = try await client.serverVersion()
                databases = try await client.metadata.listDatabases().map(\.name)
            } else {
                let client = try await PostgresClient.connect(configuration: PostgresConfiguration(
                    host: profile.host,
                    port: profile.port ?? 5432,
                    database: profile.database.flatMap { $0.isEmpty ? nil : $0 } ?? "postgres",
                    username: profile.username ?? "postgres",
                    password: profile.password,
                    useTLS: profile.useTLS ?? false))
                postgres = client
                serverVersion = try await firstCell(of: "SHOW server_version").map { "PostgreSQL \($0)" }
                databases = try await client.metadata.listDatabases()
            }
            state = .connected
            note("Connected in \(format(ContinuousClock.now - start))")
        } catch {
            state = .failed(error.localizedDescription)
            note("Failed: \(error.localizedDescription)")
        }
    }

    func disconnect() async {
        try? await mssql?.shutdownGracefully()
        postgres?.close()
        mssql = nil
        postgres = nil
        state = .idle
        structure = nil
        note("Disconnected")
    }

    // MARK: Schema for EchoSense

    /// Loads tables, views and columns of `database` (SQL Server) or the connected database
    /// (PostgreSQL) into EchoSense's structure type.
    func loadStructure(database: String?) async {
        let start = ContinuousClock.now
        do {
            if let client = mssql {
                let name = database ?? databases.first ?? "master"
                let loaded = try await client.metadata.loadDatabaseStructure(database: name, includeComments: false)
                let schemas = loaded.schemas.map { schema in
                    EchoSenseSchemaInfo(name: schema.name, objects:
                        schema.tables.map { objectInfo($0, .table) } + schema.views.map { objectInfo($0, .view) })
                }
                structure = EchoSenseDatabaseStructure(serverVersion: serverVersion, databases: [
                    EchoSenseDatabaseInfo(name: name, schemas: schemas)])
            } else if let client = postgres {
                var schemas: [EchoSenseSchemaInfo] = []
                for schema in try await client.metadata.listSchemas().map(\.name)
                where !["pg_catalog", "information_schema", "pg_toast"].contains(schema) {
                    let summary = try await client.metadata.schemaSummary(schema: schema)
                    let objects = summary.objects.compactMap { object -> EchoSenseSchemaObjectInfo? in
                        let type: EchoSenseSchemaObjectInfo.ObjectType
                        switch object.type {
                        case .table: type = .table
                        case .view: type = .view
                        case .materializedView: type = .materializedView
                        default: return nil
                        }
                        return EchoSenseSchemaObjectInfo(name: object.name, schema: schema, type: type, columns:
                            object.columns.map { column in
                                EchoSenseColumnInfo(
                                    name: column.name, dataType: column.dataType, isPrimaryKey: column.isPrimaryKey,
                                    isNullable: column.isNullable, maxLength: column.maxLength,
                                    foreignKey: column.foreignKey.map {
                                        EchoSenseForeignKeyReference(
                                            constraintName: $0.constraintName, referencedSchema: $0.referencedSchema,
                                            referencedTable: $0.referencedTable, referencedColumn: $0.referencedColumn)
                                    })
                            })
                    }
                    schemas.append(EchoSenseSchemaInfo(name: schema, objects: objects))
                }
                structure = EchoSenseDatabaseStructure(serverVersion: serverVersion, databases: [
                    EchoSenseDatabaseInfo(name: profile.database ?? "postgres", schemas: schemas)])
            }
            let count = structure?.databases.flatMap(\.schemas).flatMap(\.objects).count ?? 0
            note("Loaded \(count) objects in \(format(ContinuousClock.now - start))")
        } catch {
            note("Schema load failed: \(error.localizedDescription)")
        }
    }

    private func objectInfo(_ table: SQLServerTableStructure, _ type: EchoSenseSchemaObjectInfo.ObjectType) -> EchoSenseSchemaObjectInfo {
        let keys = Set(table.primaryKey?.columns.map { $0.column.lowercased() } ?? [])
        return EchoSenseSchemaObjectInfo(name: table.table.name, schema: table.table.schema, type: type, columns:
            table.columns.map {
                EchoSenseColumnInfo(name: $0.name, dataType: $0.typeName, isPrimaryKey: keys.contains($0.name.lowercased()),
                                    isNullable: $0.isNullable, maxLength: $0.maxLength)
            })
    }

    // MARK: Queries

    /// Runs user-authored SQL and returns text cells. PostgreSQL rows come back as JSON text
    /// through `row_to_json` when the statement is a SELECT.
    func run(_ sql: String) async throws -> QueryOutput {
        let start = ContinuousClock.now
        if let client = mssql {
            let rows = try await client.query(sql)
            let columns = rows.first?.columns.map(\.name) ?? []
            return QueryOutput(columns: columns, rows: rows.map { $0.toStringArray().map { $0 ?? "NULL" } },
                               elapsed: ContinuousClock.now - start)
        }
        if let client = postgres {
            let isSelect = sql.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("select")
            let wrapped = isSelect ? "SELECT row_to_json(q)::text FROM (\(sql.trimmingCharacters(in: CharacterSet(charactersIn: "; \n\t")))) q" : sql
            var lines: [String] = []
            for try await row in try await client.simpleQuery(wrapped) {
                lines.append(String(describing: row))
            }
            return QueryOutput(columns: [isSelect ? "row (json)" : "result"], rows: lines.map { [$0] },
                               elapsed: ContinuousClock.now - start)
        }
        throw LabConnectionError.notConnected
    }

    private func firstCell(of sql: String) async throws -> String? {
        try await run(sql).rows.first?.first
    }

    // MARK: Log

    private func note(_ text: String) {
        log.append("\(Date.now.formatted(date: .omitted, time: .standard))  \(text)")
    }

    private func format(_ duration: Duration) -> String {
        let seconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
        return String(format: "%.2fs", seconds)
    }
}

enum LabConnectionError: LocalizedError {
    case notConnected
    var errorDescription: String? { "Not connected" }
}
