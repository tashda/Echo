//
//  AppModel.swift
//  fuzee
//
//  Created by Kenneth Berg on 15/09/2025.
//

import Foundation
import SwiftUI
import Combine

/// Manages database connections and operations
@MainActor
final class AppModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var connections: [SavedConnection] = []
    @Published var selectedConnectionID: UUID?
    @Published var session: DatabaseSession?
    @Published var connectionStates: [UUID: ConnectionState] = [:]
    @Published var databaseStructure: [String: DatabaseStructure] = [:]

    // MARK: - Session Management
    @Published var sessionManager = ConnectionSessionManager()
    
    // MARK: - Dependencies
    private let store = ConnectionStore()
    private let keychain = KeychainHelper()
    private let dbFactory = PostgresNIOFactory()
    
    // MARK: - Computed Properties
    var selectedConnection: SavedConnection? {
        guard let id = selectedConnectionID else { return nil }
        return connections.first { $0.id == id }
    }
    
    // MARK: - Initialization
    init() {
        // Initialize with default values - actual loading happens in load()
    }
    
    // MARK: - Connection Management
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
        
        // Save password to keychain if provided
        if let password = password, !password.isEmpty {
            if conn.keychainIdentifier == nil {
                conn.keychainIdentifier = "fuzee.\(conn.id.uuidString)"
            }
            
            if let identifier = conn.keychainIdentifier {
                do {
                    try keychain.setPassword(password, account: identifier)
                } catch {
                    print("Keychain set failed: \(error)")
                }
            }
        }
        
        // Update or add connection
        if let index = connections.firstIndex(where: { $0.id == conn.id }) {
            connections[index] = conn
        } else {
            connections.append(conn)
        }
        
        // Save to disk
        do {
            try await store.save(connections)
        } catch {
            print("Failed to save connections: \(error)")
        }
    }
    
    func deleteConnection(id: UUID) async {
        guard let connection = connections.first(where: { $0.id == id }) else { return }
        await deleteConnection(connection)
    }
    
    func deleteConnection(_ connection: SavedConnection) async {
        // Remove from keychain
        if let identifier = connection.keychainIdentifier {
            try? keychain.deletePassword(account: identifier)
        }
        
        // Remove from connections
        connections.removeAll { $0.id == connection.id }
        connectionStates.removeValue(forKey: connection.id)
        databaseStructure.removeValue(forKey: connection.id.uuidString)
        
        // Update selection if needed
        if selectedConnectionID == connection.id {
            selectedConnectionID = connections.first?.id
        }
        
        // Save changes
        do {
            try await store.save(connections)
        } catch {
            print("Failed to save connections: \(error)")
        }
    }
    
    func connect(to connection: SavedConnection) async {
        connectionStates[connection.id] = .connecting
        
        do {
            // Get password from keychain if needed
            var password: String?
            if let identifier = connection.keychainIdentifier {
                password = try? keychain.getPassword(account: identifier)
            }
            
            // Create connection
            let newSession = try await dbFactory.connect(
                host: connection.host,
                port: connection.port,
                username: connection.username,
                password: password,
                database: connection.database,
                tls: connection.useTLS
            )
            
            // Update state
            session = newSession
            selectedConnectionID = connection.id
            connectionStates[connection.id] = .connected

            // Load database structure
            await loadDatabaseStructure(for: connection)
            
        } catch {
            let dbError = DatabaseError.from(error)
            connectionStates[connection.id] = .error(dbError)
            print("Connection failed: \(error)")
        }
    }
    
    func disconnect() async {
        if let currentSession = session {
            await currentSession.close()
            session = nil
        }

        // Reset connection states
        for id in connectionStates.keys {
            if connectionStates[id]?.isConnected == true {
                connectionStates[id] = .disconnected
            }
        }

        // Clear database structures
        databaseStructure.removeAll()
    }
    
    // MARK: - Query Operations
    func executeQuery(_ sql: String) async throws -> QueryResultSet {
        guard let session = session else {
            throw DatabaseError.connectionFailed("No active connection")
        }
        
        return try await session.simpleQuery(sql)
    }
    
    func executeUpdate(_ sql: String) async throws -> Int {
        guard let session = session else {
            throw DatabaseError.connectionFailed("No active connection")
        }
        
        return try await session.executeUpdate(sql)
    }
    
    func listTables() async throws -> [String] {
        guard let session = session else {
            throw DatabaseError.connectionFailed("No active connection")
        }
        
        let objects = try await session.listTablesAndViews(schema: "public")
        return objects.map { $0.name }
    }
    
    // MARK: - Database Structure Loading
    func loadDatabaseStructure(for connection: SavedConnection) async {
        guard let session = session else { return }

        do {
            // Get list of tables and views
            var objects = try await session.listTablesAndViews(schema: "public")

            // For each object, fetch its columns
            for i in 0..<objects.count {
                let columns = try await session.getTableSchema(objects[i].name, schemaName: objects[i].schema)
                objects[i].columns = columns
            }

            // Create database structure
            let publicSchema = SchemaInfo(name: "public", objects: objects)
            let databaseInfo = DatabaseInfo(
                name: connection.database ?? "default",
                schemas: [publicSchema]
            )

            let structure = DatabaseStructure(
                databases: [databaseInfo]
            )

            // Store the structure
            databaseStructure[connection.id.uuidString] = structure

        } catch {
            print("Failed to load database structure: \(error)")
            // Create empty structure to stop loading state
            let emptyStructure = DatabaseStructure(databases: [])
            databaseStructure[connection.id.uuidString] = emptyStructure
        }
    }

    // MARK: - Connection Testing
    func testConnection(_ connection: SavedConnection) async -> ConnectionTestResult {
        let startTime = Date()
        
        do {
            // Get password from keychain if needed
            var password: String?
            if let identifier = connection.keychainIdentifier {
                password = try? keychain.getPassword(account: identifier)
            }
            
            // Create a temporary connection for testing
            let session = try await dbFactory.connect(
                host: connection.host,
                port: connection.port,
                username: connection.username,
                password: password,
                database: connection.database,
                tls: connection.useTLS
            )
            
            // Test with a simple query
            let _ = try await session.simpleQuery("SELECT 1")
            
            // Close the test connection
            await session.close()
            
            let responseTime = Date().timeIntervalSince(startTime)
            
            return ConnectionTestResult(
                isSuccessful: true,
                message: "Connection successful",
                responseTime: responseTime,
                serverVersion: nil
            )
            
        } catch {
            let responseTime = Date().timeIntervalSince(startTime)
            let dbError = DatabaseError.from(error)
            
            return ConnectionTestResult(
                isSuccessful: false,
                message: dbError.errorDescription ?? "Connection failed",
                responseTime: responseTime,
                serverVersion: nil
            )
        }
    }

    // MARK: - MainActor Query Operations
    func executeQuery(_ sql: String) async {
        do {
            let _ = try await executeQuery(sql)
        } catch {
            print("Query execution failed: \(error)")
        }
    }

    // MARK: - Session Manager Integration
    func refreshDatabaseStructure(for sessionID: UUID) async {
        guard let session = sessionManager.activeSessions.first(where: { $0.id == sessionID }) else { return }
        await loadDatabaseStructure(for: session.connection)
    }
}

// MARK: - Connection Testing Result
public struct ConnectionTestResult {
    public let isSuccessful: Bool
    public let message: String
    public let responseTime: TimeInterval?
    public let serverVersion: String?
    
    public init(isSuccessful: Bool, message: String, responseTime: TimeInterval? = nil, serverVersion: String? = nil) {
        self.isSuccessful = isSuccessful
        self.message = message
        self.responseTime = responseTime
        self.serverVersion = serverVersion
    }
    
    // Compatibility properties for existing code
    public var success: Bool { isSuccessful }
    
    public var details: String {
        var details: [String] = []
        if let responseTime = responseTime {
            details.append("Response time: \(String(format: "%.3f", responseTime))s")
        }
        if let serverVersion = serverVersion {
            details.append("Server version: \(serverVersion)")
        }
        return details.isEmpty ? message : details.joined(separator: " • ")
    }
}
