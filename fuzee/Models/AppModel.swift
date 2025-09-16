import Foundation
import SwiftUI
import Combine

@MainActor final class AppModel: ObservableObject {
    @Published var connections: [SavedConnection] = []
    @Published var selectedConnectionID: UUID?
    @Published var session: DatabaseSession?
    @Published var databaseStructure: [String: DatabaseStructure] = [:]
    @Published var connectionStates: [UUID: ConnectionState] = [:]

    private let store = ConnectionStore()
    private let keychain = KeychainHelper()
    private let dbFactory = PostgresNIOFactory()

    var selectedConnection: SavedConnection? {
        connections.first {
            $0.id == selectedConnectionID
        }
    }

    func load() async {
        do {
            connections = try await store.load()
            if selectedConnectionID == nil {
                selectedConnectionID = connections.first?.id
            }
        } catch {
            print("Failed to load connections: \(error)")
        }
    }

    func upsertConnection(_ connection: SavedConnection, password: String?) async {
        var conn = connection
        if let password, !password.isEmpty {
            if conn.keychainIdentifier == nil {
                conn.keychainIdentifier = "fuzee.\(conn.id.uuidString)"
            }
            if let id = conn.keychainIdentifier {
                do {
                    try keychain.setPassword(password, account: id)
                } catch {
                    print("Keychain set failed: \(error)")
                }
            }
        }

        if let index = connections.firstIndex(where: {
            $0.id == conn.id
        }) {
            connections[index] = conn
        } else {
            connections.append(conn)
        }

        do {
            try await store.save(connections)
        } catch {
            print("Failed to save connections: \(error)")
        }
    }

    func deleteConnection(id: UUID) async {
        guard let idx = connections.firstIndex(where: {
            $0.id == id
        }) else {
            return
        }
        let conn = connections.remove(at: idx)
        if let kid = conn.keychainIdentifier {
            try? keychain.deletePassword(account: kid)
        }
        if selectedConnectionID == id {
            selectedConnectionID = nil
            session = nil
            databaseStructure.removeValue(forKey: id.uuidString)
        }
        connectionStates.removeValue(forKey: id)

        do {
            try await store.save(connections)
        } catch {
            print("Failed to save after delete: \(error)")
        }
    }

    func testConnection(_ connection: SavedConnection) async -> ConnectionTestResult {
        connectionStates[connection.id] = .testing

        do {
            var password: String? = nil
            if let kid = connection.keychainIdentifier {
                do {
                    password = try keychain.getPassword(account: kid)
                } catch {
                    print("Keychain getPassword failed: \(error)")
                }
            }

            let testSession = try await dbFactory.connect(
                host: connection.host,
                port: connection.port,
                username: connection.username,
                password: password,
                database: connection.database,
                tls: connection.useTLS
            )

            let result = try await testSession.simpleQuery("SELECT 1 as test")
            await testSession.close()
            connectionStates[connection.id] = .connected

            return ConnectionTestResult(
                success: true,
                message: "Connection successful",
                details: "Successfully connected and executed test query."
            )

        } catch let dbError as DatabaseError {
            connectionStates[connection.id] = .error(dbError)
            return ConnectionTestResult(
                success: false,
                message: dbError.localizedDescription,
                details: dbError.recoverySuggestion ?? "Please check your connection settings."
            )
        } catch {
            let dbError = DatabaseError.from(error)
            connectionStates[connection.id] = .error(dbError)
            return ConnectionTestResult(
                success: false,
                message: "Connection failed",
                details: error.localizedDescription
            )
        }
    }

    func connect(to connection: SavedConnection) async {
        connectionStates[connection.id] = .connecting

        do {
            let password: String? = {
                if let kid = connection.keychainIdentifier {
                    return try? keychain.getPassword(account: kid)
                }
                return nil
            }()

            let db = try await dbFactory.connect(
                host: connection.host,
                port: connection.port,
                username: connection.username,
                password: password,
                database: connection.database,
                tls: connection.useTLS
            )

            self.session = db
            connectionStates[connection.id] = .connected

            await updateConnectionInfo(connection)
            await refreshDatabaseStructure(for: connection)

        } catch let dbError as DatabaseError {
            connectionStates[connection.id] = .error(dbError)
        } catch {
            let dbError = DatabaseError.from(error)
            connectionStates[connection.id] = .error(dbError)
        }
    }

    func disconnect() async {
        if let connection = selectedConnection {
            connectionStates[connection.id] = .disconnected
        }
        await session?.close()
        session = nil
    }

    private func updateConnectionInfo(_ connection: SavedConnection) async {
        guard let session = session else {
            return
        }

        do {
            let versionResult = try await session.simpleQuery("SELECT version()")
            if let versionString = versionResult.rows.first?.first {
                if let index = connections.firstIndex(where: {
                    $0.id == connection.id
                }) {
                    connections[index].serverVersion = extractVersion(from: versionString!)
                    try await store.save(connections)
                }
            }
        } catch {
            print("Failed to get server version: \(error)")
        }
    }

    private func extractVersion(from versionString: String) -> String {
        let components = versionString.components(separatedBy: " ")
        if components.count >= 2 {
            return components[1]
        }
        return "Unknown"
    }

    private func refreshDatabaseStructure(for connection: SavedConnection) async {
        guard let session = session else {
            return
        }

        do {
            let databasesResult = try await session.simpleQuery("""
                SELECT datname FROM pg_database 
                            WHERE datistemplate = false
                            ORDER BY datname
            """)

            var databases: [DatabaseInfo] = []

            for row in databasesResult.rows {
                guard let dbName = row[0] else {
                    continue
                }

                if dbName == connection.database {
                    let schemas = try await loadSchemasForDatabase(dbName, session: session)
                    databases.append(DatabaseInfo(name: dbName, schemas: schemas, isSelected: true))
                } else {
                    databases.append(DatabaseInfo(name: dbName, schemas: [], isSelected: false))
                }
            }

            let structure = DatabaseStructure(
                serverVersion: connections.first(where: {
                    $0.id == connection.id
                })?.serverVersion,
                databases: databases
            )

            databaseStructure[connection.id.uuidString] = structure

        } catch {
            print("Failed to refresh database structure: \(error)")
            databaseStructure[connection.id.uuidString] = DatabaseStructure(databases: [])
        }
    }

    private func loadSchemasForDatabase(_ databaseName: String, session: DatabaseSession) async throws -> [SchemaInfo] {
        let schemasResult = try await session.simpleQuery("""
            SELECT schema_name 
                    FROM information_schema.schemata
                    WHERE schema_name NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
                    ORDER BY schema_name
        """)

        var schemas: [SchemaInfo] = []

        for row in schemasResult.rows {
            guard let schemaName = row[0] else {
                continue
            }

            let tablesResult = try await session.simpleQuery("""
                SELECT table_name, table_type 
                            FROM information_schema.tables
                            WHERE table_schema = '\(schemaName)'
                                AND table_type IN ('BASE TABLE', 'VIEW')
                            ORDER BY table_name
            """)

            var tables: [TableInfo] = []
            var views: [ViewInfo] = []

            for tableRow in tablesResult.rows {
                guard let tableName = tableRow[0], let tableType = tableRow[1] else {
                    continue
                }

                if tableType == "BASE TABLE" {
                    tables.append(TableInfo(name: tableName, schemaName: schemaName))
                } else if tableType == "VIEW" {
                    views.append(ViewInfo(name: tableName, schemaName: schemaName))
                }
            }

            schemas.append(SchemaInfo(name: schemaName, tables: tables, views: views))
        }

        return schemas
    }
}

struct ConnectionTestResult {
    let success: Bool
    let message: String
    let details: String
}

struct DatabaseStructure {
    let serverVersion: String?
    let databases: [DatabaseInfo]

    init(serverVersion: String? = nil, databases: [DatabaseInfo] = []) {
        self.serverVersion = serverVersion
        self.databases = databases
    }
}

struct DatabaseInfo {
    let name: String
    let schemas: [SchemaInfo]
    let isSelected: Bool

    init(name: String, schemas: [SchemaInfo] = [], isSelected: Bool = false) {
        self.name = name
        self.schemas = schemas
        self.isSelected = isSelected
    }
}

struct SchemaInfo {
    let name: String
    let tables: [TableInfo]
    let views: [ViewInfo]
}

struct TableInfo {
    let name: String
    let schemaName: String

    var fullName: String {
        return "\(schemaName).\(name)"
    }
}

struct ViewInfo {
    let name: String
    let schemaName: String

    var fullName: String {
        return "\(schemaName).\(name)"
    }
}

struct SchemaItem {
    let name: String
    let type: SchemaItemType
}

enum SchemaItemType {
    case table
    case view
}