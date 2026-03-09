import XCTest
@testable import Echo

final class ConnectionConfigurationTests: XCTestCase {

    // MARK: - Validation

    func testIsValidReturnsTrueForValidConfig() {
        let config = ConnectionConfiguration(
            connectionName: "Test",
            host: "localhost",
            port: 5432,
            database: "mydb",
            username: "user"
        )
        XCTAssertTrue(config.isValid)
        XCTAssertTrue(config.validationErrors.isEmpty)
    }

    func testValidationCatchesEmptyHost() {
        let config = ConnectionConfiguration(
            connectionName: "Test",
            host: "",
            port: 5432,
            database: "mydb",
            username: "user"
        )
        XCTAssertFalse(config.isValid)
        XCTAssertTrue(config.validationErrors.contains { $0.contains("Host") })
    }

    func testValidationCatchesPortZero() {
        let config = ConnectionConfiguration(
            connectionName: "Test",
            host: "localhost",
            port: 0,
            database: "mydb",
            username: "user"
        )
        XCTAssertFalse(config.isValid)
        XCTAssertTrue(config.validationErrors.contains { $0.contains("Port") })
    }

    func testValidationCatchesPortAbove65535() {
        let config = ConnectionConfiguration(
            connectionName: "Test",
            host: "localhost",
            port: 70000,
            database: "mydb",
            username: "user"
        )
        XCTAssertFalse(config.isValid)
        XCTAssertTrue(config.validationErrors.contains { $0.contains("Port") })
    }

    func testValidationCatchesEmptyUsername() {
        let config = ConnectionConfiguration(
            connectionName: "Test",
            host: "localhost",
            port: 5432,
            database: "mydb",
            username: ""
        )
        XCTAssertFalse(config.isValid)
        XCTAssertTrue(config.validationErrors.contains { $0.contains("Username") })
    }

    func testValidationAllowsEmptyUsernameForInheritCredentials() {
        let config = ConnectionConfiguration(
            connectionName: "Test",
            host: "localhost",
            port: 5432,
            database: "mydb",
            username: "",
            credentialSource: .inherit
        )
        XCTAssertTrue(config.isValid)
    }

    func testValidationCatchesIdentityModeWithNoIdentityID() {
        let config = ConnectionConfiguration(
            connectionName: "Test",
            host: "localhost",
            port: 5432,
            database: "mydb",
            username: "user",
            credentialSource: .identity,
            identityID: nil
        )
        XCTAssertFalse(config.isValid)
        XCTAssertTrue(config.validationErrors.contains { $0.contains("identity") })
    }

    func testValidationPassesIdentityModeWithIdentityID() {
        let config = ConnectionConfiguration(
            connectionName: "Test",
            host: "localhost",
            port: 5432,
            database: "mydb",
            username: "user",
            credentialSource: .identity,
            identityID: UUID()
        )
        XCTAssertTrue(config.isValid)
    }

    func testValidationCatchesEmptyConnectionName() {
        let config = ConnectionConfiguration(
            connectionName: "",
            host: "localhost",
            port: 5432,
            database: "mydb",
            username: "user"
        )
        XCTAssertFalse(config.isValid)
        XCTAssertTrue(config.validationErrors.contains { $0.contains("Connection name") })
    }

    func testValidationCatchesEmptyDatabase() {
        let config = ConnectionConfiguration(
            connectionName: "Test",
            host: "localhost",
            port: 5432,
            database: "",
            username: "user"
        )
        XCTAssertFalse(config.isValid)
        XCTAssertTrue(config.validationErrors.contains { $0.contains("Database") })
    }

    // MARK: - Conversion

    func testAsSavedConnectionProducesCorrectFields() {
        let id = UUID()
        let config = ConnectionConfiguration(
            connectionName: "PG Prod",
            host: "db.example.com",
            port: 5432,
            database: "production",
            username: "admin",
            useTLS: true,
            id: id
        )

        let saved = config.asSavedConnection
        XCTAssertEqual(saved.id, id)
        XCTAssertEqual(saved.connectionName, "PG Prod")
        XCTAssertEqual(saved.host, "db.example.com")
        XCTAssertEqual(saved.port, 5432)
        XCTAssertEqual(saved.database, "production")
        XCTAssertEqual(saved.username, "admin")
        XCTAssertEqual(saved.useTLS, true)
    }

    func testFromSavedConnectionRoundTrip() {
        let saved = TestFixtures.savedConnection(
            connectionName: "Round Trip",
            host: "10.0.0.1",
            port: 3306,
            database: "mydb",
            username: "root",
            useTLS: false
        )

        let config = ConnectionConfiguration.from(saved)
        XCTAssertEqual(config.connectionName, saved.connectionName)
        XCTAssertEqual(config.host, saved.host)
        XCTAssertEqual(config.port, saved.port)
        XCTAssertEqual(config.database, saved.database)
        XCTAssertEqual(config.username, saved.username)
        XCTAssertEqual(config.useTLS, saved.useTLS)
        XCTAssertEqual(config.id, saved.id)
    }
}
