//
//  ConnectionManager.swift
//  fuzee
//
//  Created by Assistant on 23/09/2025.
//

import Foundation
import SwiftUI
import Combine

/// Manages database connections and operations
@MainActor
final class ConnectionManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var connections: [SavedConnection] = []
    @Published var selectedConnectionID: UUID?
    @Published var currentSession: DatabaseSession?
    @Published var connectionStates: [UUID: ConnectionState] = [:]
    @Published var isConnecting = false
    @Published var lastError: DatabaseError?
    
    // MARK: - Dependencies
    private let connectionStore = ConnectionStore()
    private let keychainHelper = KeychainHelper()
    private let databaseFactory = PostgresNIOFactory()
    
    // MARK: - Computed Properties
    var selectedConnection: SavedConnection? {
        guard let id = selectedConnectionID else { return nil }
        return connections.first { $0.id == id }
    }
    
    var isConnected: Bool {
        currentSession != nil
    }
    
    // MARK: - Initialization
    init() {
        Task {
            await loadConnections()
        }
    }
    
    // MARK: - Connection Management
    func loadConnections() async {
        do {
            connections = try await connectionStore.load()
            if selectedConnectionID == nil {
                selectedConnectionID = connections.first?.id
            }
        } catch {
            lastError = DatabaseError.from(error)
        }
    }
    
    func saveConnection(_ connection: SavedConnection, password: String? = nil) async {
        var conn = connection
        
        // Save password to keychain if provided
        if let password = password, !password.isEmpty {
            if conn.keychainIdentifier == nil {
                conn.keychainIdentifier = "fuzee.\(conn.id.uuidString)"
            }
            
            if let identifier = conn.keychainIdentifier {
                do {
                    try keychainHelper.setPassword(password, account: identifier)
                } catch {
                    lastError = DatabaseError.from(error)
                    return
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
            try await connectionStore.save(connections)
        } catch {
            lastError = DatabaseError.from(error)
        }
    }
    
    func deleteConnection(_ connection: SavedConnection) async {
        // Remove from keychain
        if let identifier = connection.keychainIdentifier {
            try? keychainHelper.deletePassword(account: identifier)
        }
        
        // Remove from connections
        connections.removeAll { $0.id == connection.id }
        connectionStates.removeValue(forKey: connection.id)
        
        // Update selection if needed
        if selectedConnectionID == connection.id {
            selectedConnectionID = connections.first?.id
        }
        
        // Save changes
        do {
            try await connectionStore.save(connections)
        } catch {
            lastError = DatabaseError.from(error)
        }
    }
    
    func connect(to connection: SavedConnection) async {
        isConnecting = true
        connectionStates[connection.id] = .connecting
        
        do {
            // Get password from keychain if needed
            var password: String?
            if let identifier = connection.keychainIdentifier {
                password = try? keychainHelper.getPassword(account: identifier)
            }
            
            // Create connection
            let session = try await databaseFactory.connect(
                host: connection.host,
                port: connection.port,
                username: connection.username,
                password: password,
                database: connection.database,
                tls: connection.useTLS
            )
            
            // Update state
            currentSession = session
            selectedConnectionID = connection.id
            connectionStates[connection.id] = .connected
            lastError = nil
            
        } catch {
            let dbError = DatabaseError.from(error)
            connectionStates[connection.id] = .error(dbError)
            lastError = dbError
        }
        
        isConnecting = false
    }
    
    func disconnect() async {
        if let session = currentSession {
            await session.close()
            currentSession = nil
        }
        
        // Reset connection states
        for id in connectionStates.keys {
            if connectionStates[id]?.isConnected == true {
                connectionStates[id] = .disconnected
            }
        }
    }
    
    // MARK: - Query Operations
    func executeQuery(_ sql: String) async throws -> QueryResultSet {
        guard let session = currentSession else {
            throw DatabaseError.connectionFailed("No active connection")
        }
        
        return try await session.simpleQuery(sql)
    }
    
    func executeUpdate(_ sql: String) async throws -> Int {
        guard let session = currentSession else {
            throw DatabaseError.connectionFailed("No active connection")
        }
        
        return try await session.executeUpdate(sql)
    }
    
    func listTables() async throws -> [String] {
        guard let session = currentSession else {
            throw DatabaseError.connectionFailed("No active connection")
        }
        
        let objects = try await session.listTablesAndViews(schema: "public")
        return objects.map { $0.name }
    }
    
    // MARK: - Connection Testing
    func testConnection(_ connection: SavedConnection) async -> ConnectionTestResult {
        let startTime = Date()
        
        do {
            // Get password from keychain if needed
            var password: String?
            if let identifier = connection.keychainIdentifier {
                password = try? keychainHelper.getPassword(account: identifier)
            }
            
            // Create a temporary connection for testing
            let session = try await databaseFactory.connect(
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
}
