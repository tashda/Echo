import XCTest
@testable import Echo

final class SavedConnectionTests: XCTestCase {

    // MARK: - Codable Round-Trip

    func testCodableRoundTrip() throws {
        let connection = TestFixtures.savedConnection(
            connectionName: "Production",
            host: "db.example.com",
            port: 5432,
            database: "myapp",
            username: "admin",
            useTLS: true,
            databaseType: .postgresql,
            serverVersion: "15.2",
            colorHex: "FF5733"
        )

        let data = try JSONEncoder().encode(connection)
        let decoded = try JSONDecoder().decode(SavedConnection.self, from: data)

        XCTAssertEqual(decoded.id, connection.id)
        XCTAssertEqual(decoded.connectionName, "Production")
        XCTAssertEqual(decoded.host, "db.example.com")
        XCTAssertEqual(decoded.port, 5432)
        XCTAssertEqual(decoded.database, "myapp")
        XCTAssertEqual(decoded.username, "admin")
        XCTAssertEqual(decoded.useTLS, true)
        XCTAssertEqual(decoded.databaseType, .postgresql)
        XCTAssertEqual(decoded.serverVersion, "15.2")
        XCTAssertEqual(decoded.colorHex, "FF5733")
    }

    func testCodableRoundTripAllDatabaseTypes() throws {
        for dbType in DatabaseType.allCases {
            let connection = TestFixtures.savedConnection(databaseType: dbType)
            let data = try JSONEncoder().encode(connection)
            let decoded = try JSONDecoder().decode(SavedConnection.self, from: data)
            XCTAssertEqual(decoded.databaseType, dbType, "Round-trip failed for \(dbType)")
        }
    }

    // MARK: - Legacy Decoding

    func testLegacyDecodingMissingOptionalFields() throws {
        let json: [String: Any] = [
            "connectionName": "Legacy",
            "host": "localhost",
            "port": 5432,
            "database": "test"
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(SavedConnection.self, from: data)

        XCTAssertEqual(decoded.connectionName, "Legacy")
        XCTAssertEqual(decoded.username, "")
        XCTAssertEqual(decoded.authenticationMethod, .sqlPassword)
        XCTAssertEqual(decoded.domain, "")
        XCTAssertEqual(decoded.credentialSource, .manual)
        XCTAssertNil(decoded.identityID)
        XCTAssertTrue(decoded.useTLS)
        XCTAssertEqual(decoded.databaseType, .postgresql)
        XCTAssertEqual(decoded.colorHex, "")
    }

    // MARK: - Computed Properties

    func testUsesInheritedCredentials() {
        var connection = TestFixtures.savedConnection(credentialSource: .inherit)
        XCTAssertTrue(connection.usesInheritedCredentials)

        connection = TestFixtures.savedConnection(credentialSource: .manual)
        XCTAssertFalse(connection.usesInheritedCredentials)
    }

    func testUsesIdentity() {
        let identityID = UUID()
        var connection = TestFixtures.savedConnection(credentialSource: .identity, identityID: identityID)
        XCTAssertTrue(connection.usesIdentity)

        connection = TestFixtures.savedConnection(credentialSource: .identity, identityID: nil)
        XCTAssertFalse(connection.usesIdentity)

        connection = TestFixtures.savedConnection(credentialSource: .manual, identityID: identityID)
        XCTAssertFalse(connection.usesIdentity)
    }

    // MARK: - Equality

    func testEqualityByID() {
        let id = UUID()
        let a = TestFixtures.savedConnection(id: id, connectionName: "A")
        let b = TestFixtures.savedConnection(id: id, connectionName: "B")
        XCTAssertEqual(a, b, "Connections with same ID should be equal regardless of other fields")
    }

    func testInequalityByID() {
        let a = TestFixtures.savedConnection(connectionName: "Same Name")
        let b = TestFixtures.savedConnection(connectionName: "Same Name")
        XCTAssertNotEqual(a, b, "Connections with different IDs should not be equal")
    }

    // MARK: - trustServerCertificate

    func testCodableRoundTripPreservesTrustServerCertificateTrue() throws {
        let connection = TestFixtures.savedConnection(
            connectionName: "MSSQL Dev",
            host: "sql.example.com",
            port: 1433,
            database: "devdb",
            username: "sa",
            useTLS: true,
            trustServerCertificate: true,
            databaseType: .microsoftSQL
        )

        let data = try JSONEncoder().encode(connection)
        let decoded = try JSONDecoder().decode(SavedConnection.self, from: data)

        XCTAssertEqual(decoded.trustServerCertificate, true)
    }

    func testDecodingMissingTrustServerCertificateDefaultsToFalse() throws {
        let json: [String: Any] = [
            "connectionName": "Legacy MSSQL",
            "host": "oldserver",
            "port": 1433,
            "database": "legacydb"
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(SavedConnection.self, from: data)

        XCTAssertFalse(decoded.trustServerCertificate, "Missing trustServerCertificate should default to false")
    }

    func testEncodingIncludesTrustServerCertificateKey() throws {
        let connection = TestFixtures.savedConnection(trustServerCertificate: true)

        let data = try JSONEncoder().encode(connection)
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(jsonObject?["trustServerCertificate"], "Encoded JSON should contain trustServerCertificate key")
        XCTAssertEqual(jsonObject?["trustServerCertificate"] as? Bool, true)
    }
}
