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

    // MARK: - trustServerCertificate

    func testAsSavedConnectionPreservesTrustServerCertificateTrue() {
        let config = ConnectionConfiguration(
            connectionName: "MSSQL",
            host: "sql.example.com",
            port: 1433,
            database: "mydb",
            username: "sa",
            useTLS: true,
            trustServerCertificate: true
        )

        let saved = config.asSavedConnection
        XCTAssertTrue(saved.trustServerCertificate, "asSavedConnection should preserve trustServerCertificate: true")
    }

    func testFromSavedConnectionPreservesTrustServerCertificateTrue() {
        let saved = TestFixtures.savedConnection(
            connectionName: "MSSQL",
            host: "sql.example.com",
            port: 1433,
            database: "mydb",
            username: "sa",
            useTLS: true,
            trustServerCertificate: true,
            databaseType: .microsoftSQL
        )

        let config = ConnectionConfiguration.from(saved)
        XCTAssertTrue(config.trustServerCertificate, "from(savedConnection) should preserve trustServerCertificate: true")
    }

    func testTrustServerCertificateDefaultsToFalse() {
        let config = ConnectionConfiguration(
            connectionName: "Default",
            host: "localhost",
            port: 5432,
            database: "mydb",
            username: "user"
        )

        XCTAssertFalse(config.trustServerCertificate, "Default trustServerCertificate should be false")
    }

    // MARK: - readOnlyIntent

    func testReadOnlyIntentDefaultsToFalse() {
        let config = ConnectionConfiguration(
            connectionName: "Default",
            host: "localhost",
            port: 1433,
            database: "mydb",
            username: "sa"
        )
        XCTAssertFalse(config.readOnlyIntent)
    }

    func testAsSavedConnectionPreservesReadOnlyIntentTrue() {
        let config = ConnectionConfiguration(
            connectionName: "MSSQL AG",
            host: "sql.example.com",
            port: 1433,
            database: "mydb",
            username: "sa",
            readOnlyIntent: true
        )

        let saved = config.asSavedConnection
        XCTAssertTrue(saved.readOnlyIntent)
    }

    func testFromSavedConnectionPreservesReadOnlyIntent() {
        let saved = TestFixtures.savedConnection(
            connectionName: "MSSQL AG",
            host: "sql.example.com",
            port: 1433,
            database: "mydb",
            username: "sa",
            databaseType: .microsoftSQL
        )

        var mutableSaved = saved
        mutableSaved.readOnlyIntent = true

        let config = ConnectionConfiguration.from(mutableSaved)
        XCTAssertTrue(config.readOnlyIntent)
    }
}

// MARK: - Extended Tests (Swift Testing)

import Testing

@Suite("ConnectionConfiguration - Validation")
struct ConnectionConfigurationValidationTests {

    @Test func validConfigHasNoErrors() {
        let config = ConnectionConfiguration(
            connectionName: "Test",
            host: "localhost",
            port: 5432,
            database: "mydb",
            username: "user"
        )
        #expect(config.isValid)
        #expect(config.validationErrors.isEmpty)
    }

    @Test func whitespaceOnlyNameIsInvalid() {
        let config = ConnectionConfiguration(
            connectionName: "   ",
            host: "localhost",
            port: 5432,
            database: "mydb",
            username: "user"
        )
        #expect(!config.isValid)
        #expect(config.validationErrors.contains { $0.contains("Connection name") })
    }

    @Test func whitespaceOnlyHostIsInvalid() {
        let config = ConnectionConfiguration(
            connectionName: "Test",
            host: "  \t  ",
            port: 5432,
            database: "mydb",
            username: "user"
        )
        #expect(!config.isValid)
        #expect(config.validationErrors.contains { $0.contains("Host") })
    }

    @Test func whitespaceOnlyDatabaseIsInvalid() {
        let config = ConnectionConfiguration(
            connectionName: "Test",
            host: "localhost",
            port: 5432,
            database: "   ",
            username: "user"
        )
        #expect(!config.isValid)
        #expect(config.validationErrors.contains { $0.contains("Database") })
    }

    @Test func whitespaceOnlyUsernameIsInvalid() {
        let config = ConnectionConfiguration(
            connectionName: "Test",
            host: "localhost",
            port: 5432,
            database: "mydb",
            username: "   "
        )
        #expect(!config.isValid)
        #expect(config.validationErrors.contains { $0.contains("Username") })
    }

    @Test func portBoundaryValues() {
        let portOne = ConnectionConfiguration(
            connectionName: "Test", host: "localhost", port: 1,
            database: "mydb", username: "user"
        )
        #expect(portOne.isValid)

        let port65535 = ConnectionConfiguration(
            connectionName: "Test", host: "localhost", port: 65535,
            database: "mydb", username: "user"
        )
        #expect(port65535.isValid)

        let portNegative = ConnectionConfiguration(
            connectionName: "Test", host: "localhost", port: -1,
            database: "mydb", username: "user"
        )
        #expect(!portNegative.isValid)
        #expect(portNegative.validationErrors.contains { $0.contains("Port") })

        let port65536 = ConnectionConfiguration(
            connectionName: "Test", host: "localhost", port: 65536,
            database: "mydb", username: "user"
        )
        #expect(!port65536.isValid)
    }

    @Test func multipleValidationErrors() {
        let config = ConnectionConfiguration(
            connectionName: "",
            host: "",
            port: 0,
            database: "",
            username: ""
        )
        #expect(!config.isValid)
        let errors = config.validationErrors
        #expect(errors.count >= 5)
        #expect(errors.contains { $0.contains("Connection name") })
        #expect(errors.contains { $0.contains("Host") })
        #expect(errors.contains { $0.contains("Database") })
        #expect(errors.contains { $0.contains("Username") })
        #expect(errors.contains { $0.contains("Port") })
    }

    @Test func inheritCredentialSourceAllowsEmptyUsername() {
        let config = ConnectionConfiguration(
            connectionName: "Test",
            host: "localhost",
            port: 5432,
            database: "mydb",
            username: "",
            credentialSource: .inherit
        )
        #expect(config.isValid)
        #expect(!config.validationErrors.contains { $0.contains("Username") })
    }

    @Test func identityCredentialSourceRequiresIdentityID() {
        let noID = ConnectionConfiguration(
            connectionName: "Test",
            host: "localhost",
            port: 5432,
            database: "mydb",
            username: "user",
            credentialSource: .identity,
            identityID: nil
        )
        #expect(!noID.isValid)
        #expect(noID.validationErrors.contains { $0.contains("identity") })

        let withID = ConnectionConfiguration(
            connectionName: "Test",
            host: "localhost",
            port: 5432,
            database: "mydb",
            username: "user",
            credentialSource: .identity,
            identityID: UUID()
        )
        #expect(withID.isValid)
    }

    @Test func negativeConnectionTimeoutProducesError() {
        var config = ConnectionConfiguration(
            connectionName: "Test", host: "localhost", port: 5432,
            database: "mydb", username: "user"
        )
        config.connectionTimeout = -5
        #expect(config.validationErrors.contains { $0.contains("Connection timeout") })
    }

    @Test func zeroConnectionTimeoutProducesError() {
        var config = ConnectionConfiguration(
            connectionName: "Test", host: "localhost", port: 5432,
            database: "mydb", username: "user"
        )
        config.connectionTimeout = 0
        #expect(config.validationErrors.contains { $0.contains("Connection timeout") })
    }

    @Test func negativeQueryTimeoutProducesError() {
        var config = ConnectionConfiguration(
            connectionName: "Test", host: "localhost", port: 5432,
            database: "mydb", username: "user"
        )
        config.queryTimeout = -1
        #expect(config.validationErrors.contains { $0.contains("Query timeout") })
    }

    @Test func zeroQueryTimeoutProducesError() {
        var config = ConnectionConfiguration(
            connectionName: "Test", host: "localhost", port: 5432,
            database: "mydb", username: "user"
        )
        config.queryTimeout = 0
        #expect(config.validationErrors.contains { $0.contains("Query timeout") })
    }
}

@Suite("ConnectionConfiguration - Round Trip Conversion")
struct ConnectionConfigurationRoundTripTests {

    @Test func asSavedConnectionPreservesAllFields() {
        let id = UUID()
        let identityID = UUID()
        let folderID = UUID()
        let config = ConnectionConfiguration(
            connectionName: "Full Config",
            host: "db.example.com",
            port: 5433,
            database: "production",
            username: "admin",
            authenticationMethod: .sqlPassword,
            domain: "CORP",
            keychainIdentifier: "kc-123",
            credentialSource: .manual,
            identityID: identityID,
            folderID: folderID,
            useTLS: true,
            trustServerCertificate: true,
            tlsMode: .verifyFull,
            sslRootCertPath: "/path/to/root.crt",
            sslCertPath: "/path/to/client.crt",
            sslKeyPath: "/path/to/client.key",
            mssqlEncryptionMode: .strict,
            readOnlyIntent: true,
            id: id
        )

        let saved = config.asSavedConnection
        #expect(saved.id == id)
        #expect(saved.connectionName == "Full Config")
        #expect(saved.host == "db.example.com")
        #expect(saved.port == 5433)
        #expect(saved.database == "production")
        #expect(saved.username == "admin")
        #expect(saved.domain == "CORP")
        #expect(saved.credentialSource == .manual)
        #expect(saved.identityID == identityID)
        #expect(saved.keychainIdentifier == "kc-123")
        #expect(saved.folderID == folderID)
        #expect(saved.useTLS == true)
        #expect(saved.trustServerCertificate == true)
        #expect(saved.tlsMode == .verifyFull)
        #expect(saved.sslRootCertPath == "/path/to/root.crt")
        #expect(saved.sslCertPath == "/path/to/client.crt")
        #expect(saved.sslKeyPath == "/path/to/client.key")
        #expect(saved.mssqlEncryptionMode == .strict)
        #expect(saved.readOnlyIntent == true)
    }

    @Test func fromSavedConnectionPreservesAllFields() {
        let id = UUID()
        let identityID = UUID()
        let folderID = UUID()
        var saved = SavedConnection(
            id: id,
            connectionName: "Round Trip",
            host: "10.0.0.1",
            port: 1433,
            database: "mydb",
            username: "sa",
            authenticationMethod: .sqlPassword,
            domain: "DOMAIN",
            credentialSource: .identity,
            identityID: identityID,
            keychainIdentifier: "kc-abc",
            folderID: folderID,
            useTLS: true,
            trustServerCertificate: true,
            tlsMode: .require,
            sslRootCertPath: "/root.pem",
            sslCertPath: "/client.pem",
            sslKeyPath: "/client.key",
            mssqlEncryptionMode: .mandatory,
            readOnlyIntent: true,
            databaseType: .microsoftSQL
        )

        let config = ConnectionConfiguration.from(saved)
        #expect(config.id == id)
        #expect(config.connectionName == "Round Trip")
        #expect(config.host == "10.0.0.1")
        #expect(config.port == 1433)
        #expect(config.database == "mydb")
        #expect(config.username == "sa")
        #expect(config.domain == "DOMAIN")
        #expect(config.credentialSource == .identity)
        #expect(config.identityID == identityID)
        #expect(config.keychainIdentifier == "kc-abc")
        #expect(config.folderID == folderID)
        #expect(config.useTLS == true)
        #expect(config.trustServerCertificate == true)
        #expect(config.tlsMode == .require)
        #expect(config.sslRootCertPath == "/root.pem")
        #expect(config.sslCertPath == "/client.pem")
        #expect(config.sslKeyPath == "/client.key")
        #expect(config.mssqlEncryptionMode == .mandatory)
        #expect(config.readOnlyIntent == true)
    }

    @Test func roundTripConversionPreservesID() {
        let id = UUID()
        let config = ConnectionConfiguration(
            connectionName: "Test", host: "localhost", port: 5432,
            database: "db", username: "user", id: id
        )
        let saved = config.asSavedConnection
        let roundTripped = ConnectionConfiguration.from(saved)
        #expect(roundTripped.id == id)
        #expect(roundTripped.connectionName == config.connectionName)
        #expect(roundTripped.host == config.host)
        #expect(roundTripped.port == config.port)
    }
}

@Suite("TLSMode")
struct TLSModeTests {

    @Test func requiresTLSForEachMode() {
        #expect(!TLSMode.disable.requiresTLS)
        #expect(!TLSMode.allow.requiresTLS)
        #expect(TLSMode.prefer.requiresTLS)
        #expect(TLSMode.require.requiresTLS)
        #expect(TLSMode.verifyCA.requiresTLS)
        #expect(TLSMode.verifyFull.requiresTLS)
    }

    @Test func descriptionContainsMeaningfulText() {
        #expect(TLSMode.disable.description.contains("Disable"))
        #expect(TLSMode.allow.description.contains("Allow"))
        #expect(TLSMode.prefer.description.contains("Prefer"))
        #expect(TLSMode.require.description.contains("Require"))
        #expect(TLSMode.verifyCA.description.contains("Verify CA"))
        #expect(TLSMode.verifyFull.description.contains("Verify Full"))
    }

    @Test func rawValues() {
        #expect(TLSMode.disable.rawValue == "disable")
        #expect(TLSMode.allow.rawValue == "allow")
        #expect(TLSMode.prefer.rawValue == "prefer")
        #expect(TLSMode.require.rawValue == "require")
        #expect(TLSMode.verifyCA.rawValue == "verify-ca")
        #expect(TLSMode.verifyFull.rawValue == "verify-full")
    }

    @Test func caseIterableContainsAllModes() {
        #expect(TLSMode.allCases.count == 6)
    }

    @Test func codableRoundTrip() throws {
        for mode in TLSMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(TLSMode.self, from: data)
            #expect(decoded == mode)
        }
    }
}

@Suite("MSSQLEncryptionMode")
struct MSSQLEncryptionModeTests {

    @Test func descriptions() {
        #expect(MSSQLEncryptionMode.optional.description.contains("Optional"))
        #expect(MSSQLEncryptionMode.mandatory.description.contains("Mandatory"))
        #expect(MSSQLEncryptionMode.strict.description.contains("Strict"))
    }

    @Test func rawValues() {
        #expect(MSSQLEncryptionMode.optional.rawValue == "optional")
        #expect(MSSQLEncryptionMode.mandatory.rawValue == "mandatory")
        #expect(MSSQLEncryptionMode.strict.rawValue == "strict")
    }

    @Test func caseIterableContainsAllModes() {
        #expect(MSSQLEncryptionMode.allCases.count == 3)
    }

    @Test func codableRoundTrip() throws {
        for mode in MSSQLEncryptionMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(MSSQLEncryptionMode.self, from: data)
            #expect(decoded == mode)
        }
    }
}

@Suite("ConnectionConfiguration - Templates")
struct ConnectionConfigurationTemplateTests {

    @Test func templatesExist() {
        #expect(!ConnectionConfiguration.templates.isEmpty)
    }

    @Test func templatesHaveNonEmptyNames() {
        for template in ConnectionConfiguration.templates {
            #expect(!template.name.isEmpty)
            #expect(!template.description.isEmpty)
        }
    }

    @Test func localPostgreSQLTemplateHasCorrectDefaults() {
        guard let local = ConnectionConfiguration.templates.first(where: { $0.name == "Local PostgreSQL" }) else {
            Issue.record("Local PostgreSQL template not found")
            return
        }
        #expect(local.configuration.host == "localhost")
        #expect(local.configuration.port == 5432)
        #expect(local.configuration.database == "postgres")
        #expect(local.configuration.useTLS == false)
        #expect(local.configuration.tlsMode == .disable)
    }

    @Test func secureRemoteTemplateHasVerifyFull() {
        guard let secure = ConnectionConfiguration.templates.first(where: { $0.name == "Secure Remote Server" }) else {
            Issue.record("Secure Remote Server template not found")
            return
        }
        #expect(secure.configuration.useTLS == true)
        #expect(secure.configuration.tlsMode == .verifyFull)
    }

    @Test func dockerTemplateHasShortTimeout() {
        guard let docker = ConnectionConfiguration.templates.first(where: { $0.name == "Docker Container" }) else {
            Issue.record("Docker Container template not found")
            return
        }
        #expect(docker.configuration.connectionTimeout == 5)
        #expect(docker.configuration.useTLS == false)
    }
}

@Suite("ConnectionConfiguration - Default Values")
struct ConnectionConfigurationDefaultsTests {

    @Test func defaultValues() {
        let config = ConnectionConfiguration(
            connectionName: "Test", host: "localhost", port: 5432,
            database: "mydb", username: "user"
        )
        #expect(config.useTLS == true)
        #expect(config.trustServerCertificate == false)
        #expect(config.tlsMode == .prefer)
        #expect(config.verifySSLCertificate == true)
        #expect(config.mssqlEncryptionMode == .optional)
        #expect(config.readOnlyIntent == false)
        #expect(config.connectionTimeout == 30)
        #expect(config.queryTimeout == 60)
        #expect(config.maxRetries == 3)
        #expect(config.applicationName == "Echo")
        #expect(config.searchPath == ["public"])
        #expect(config.autocommit == true)
        #expect(config.useConnectionPooling == false)
        #expect(config.maxPoolSize == 10)
        #expect(config.minPoolSize == 1)
        #expect(config.sslRootCertPath == nil)
        #expect(config.sslCertPath == nil)
        #expect(config.sslKeyPath == nil)
        #expect(config.domain == "")
        #expect(config.keychainIdentifier == nil)
        #expect(config.credentialSource == .manual)
        #expect(config.identityID == nil)
        #expect(config.folderID == nil)
    }

    @Test func hashableConformance() {
        let config1 = ConnectionConfiguration(
            connectionName: "Test", host: "localhost", port: 5432,
            database: "mydb", username: "user"
        )
        var config2 = config1
        // Same content, same hash
        #expect(config1.hashValue == config2.hashValue)

        config2.host = "remote"
        #expect(config1 != config2)
    }
}
