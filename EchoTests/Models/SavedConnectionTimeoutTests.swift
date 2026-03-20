import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("SavedConnection - Timeout Persistence")
struct SavedConnectionTimeoutTests {
    @Test func defaultTimeoutValues() {
        let conn = SavedConnection(
            connectionName: "Test", host: "localhost", port: 5432,
            database: "db", username: "user", databaseType: .postgresql
        )
        #expect(conn.connectionTimeout == 30)
        #expect(conn.queryTimeout == 60)
    }

    @Test func customTimeoutValues() {
        let conn = SavedConnection(
            connectionName: "Test", host: "localhost", port: 5432,
            database: "db", username: "user",
            connectionTimeout: 15, queryTimeout: 120,
            databaseType: .postgresql
        )
        #expect(conn.connectionTimeout == 15)
        #expect(conn.queryTimeout == 120)
    }

    @Test func timeoutCodableRoundTrip() throws {
        let conn = SavedConnection(
            connectionName: "Test", host: "localhost", port: 5432,
            database: "db", username: "user",
            connectionTimeout: 45, queryTimeout: 90,
            databaseType: .postgresql
        )
        let data = try JSONEncoder().encode(conn)
        let decoded = try JSONDecoder().decode(SavedConnection.self, from: data)
        #expect(decoded.connectionTimeout == 45)
        #expect(decoded.queryTimeout == 90)
    }

    @Test func decodingWithoutTimeoutUsesDefaults() throws {
        // Simulate a JSON from before timeouts were added
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "connectionName": "Old",
            "host": "localhost",
            "port": 5432,
            "database": "db",
            "username": "user",
            "databaseType": "postgresql",
            "useTLS": false,
            "trustServerCertificate": false,
            "colorHex": ""
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SavedConnection.self, from: json)
        #expect(decoded.connectionTimeout == 30)
        #expect(decoded.queryTimeout == 60)
    }

    @Test func connectionConfigurationRoundTrip() {
        let conn = SavedConnection(
            connectionName: "Test", host: "localhost", port: 5432,
            database: "db", username: "user",
            connectionTimeout: 10, queryTimeout: 300,
            databaseType: .postgresql
        )
        let config = ConnectionConfiguration.from(conn)
        #expect(config.connectionTimeout == 10)
        #expect(config.queryTimeout == 300)

        let saved = config.asSavedConnection
        #expect(saved.connectionTimeout == 10)
        #expect(saved.queryTimeout == 300)
    }
}
