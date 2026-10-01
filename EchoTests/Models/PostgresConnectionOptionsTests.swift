import Foundation
import Testing
@testable import Echo

/// Echo Labs round 23: several PostgreSQL servers, Kerberos and client certificates in the
/// connection sheet.
@Suite("PostgreSQL connection options (round 23)")
struct PostgresConnectionOptionsTests {
    // MARK: Pasting (PU1)

    @Test func aURLWithSeveralServersFillsARowPerServer() throws {
        let result = try #require(ConnectionStringParser.parse(
            "postgres://alice@db1.corp.example.com:5432,db2.corp.example.com:5433,db3/app?target_session_attrs=primary&load_balance_hosts=random&krbsrvname=pg"))
        #expect(result.host == "db1.corp.example.com")
        #expect(result.port == 5432)
        #expect(result.database == "app")
        #expect(result.username == "alice")
        #expect(result.additionalHosts == [ConnectionHost(host: "db2.corp.example.com", port: 5433), ConnectionHost(host: "db3", port: nil)])
        #expect(result.targetSessionAttributes == .primary)
        #expect(result.loadBalanceHosts)
        #expect(result.kerberosServiceName == "pg")
    }

    @Test func aSingleServerURLHasNoExtraServers() throws {
        let result = try #require(ConnectionStringParser.parse("postgresql://db.example.com/sales?target_session_attrs=read-write"))
        #expect(result.additionalHosts.isEmpty)
        #expect(result.targetSessionAttributes == .readWrite)
        #expect(!result.loadBalanceHosts)
    }

    // MARK: Saving

    @Test func theNewSettingsSurviveSavingAndOldConnectionsLoad() throws {
        var connection = SavedConnection(connectionName: "Reporting", host: "db1", port: 5432, database: "app", username: "alice",
                                         authenticationMethod: .kerberos)
        connection.additionalHosts = [ConnectionHost(host: "db2", port: 5433)]
        connection.targetSessionAttributes = .standby
        connection.kerberosServiceName = "pg"
        let decoded = try JSONDecoder().decode(SavedConnection.self, from: JSONEncoder().encode(connection))
        #expect(decoded.additionalHosts == connection.additionalHosts)
        #expect(decoded.targetSessionAttributes == .standby)
        #expect(decoded.kerberosServiceName == "pg")
        #expect(decoded.authenticationMethod == .kerberos)

        let old = SavedConnection(connectionName: "Old", host: "db", port: 5432, database: "app", username: "bob")
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
        json.removeValue(forKey: "additionalHosts")
        json.removeValue(forKey: "targetSessionAttributes")
        let reloaded = try JSONDecoder().decode(SavedConnection.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(reloaded.additionalHosts.isEmpty)
        #expect(reloaded.targetSessionAttributes == .any)
    }

    // MARK: Sign-in words (KP1, KN1)

    @Test func postgresOffersPasswordAndKerberos() {
        #expect(DatabaseType.postgresql.supportedAuthenticationMethods == [.sqlPassword, .kerberos])
        #expect(DatabaseAuthenticationMethod.sqlPassword.displayName(for: .postgresql) == "Password")
        #expect(DatabaseAuthenticationMethod.sqlPassword.displayName(for: .microsoftSQL) == "SQL authentication")
        #expect(DatabaseAuthenticationMethod.kerberos.displayName(for: .postgresql) == "Kerberos")
        #expect(!DatabaseAuthenticationMethod.kerberos.usesPassword)
    }

    @Test func kerberosSendsNoPasswordButPasswordConnectionsKeepTheTicket() {
        let connection = SavedConnection(connectionName: "R", host: "db1", port: 5432, database: "app", username: "alice",
                                         authenticationMethod: .kerberos)
        let kerberos = PostgresNIOFactory.makeConfiguration(
            for: connection, database: "app",
            authentication: .init(method: .kerberos, username: "alice", password: "stale"), connectTimeoutSeconds: 5)
        #expect(kerberos.password == nil)
        #expect(kerberos.kerberosServiceName == "postgres")
        let password = PostgresNIOFactory.makeConfiguration(
            for: connection, database: "app",
            authentication: .init(method: .sqlPassword, username: "alice", password: "pw"), connectTimeoutSeconds: 5)
        #expect(password.password == "pw")
        #expect(password.kerberosServiceName == "postgres", "a server that asks for Kerberos still gets the ticket (PK1)")
    }

    @Test func extraServersAndConnectToReachTheDriver() {
        var connection = SavedConnection(connectionName: "R", host: "db1", port: 5432, database: "app", username: "alice")
        connection.additionalHosts = [ConnectionHost(host: "db2", port: nil), ConnectionHost(host: "db3", port: 6432)]
        connection.targetSessionAttributes = .primary
        let configuration = PostgresNIOFactory.makeConfiguration(
            for: connection, database: nil, authentication: .init(username: "alice", password: "pw"), connectTimeoutSeconds: 5)
        #expect(configuration.additionalHosts.map(\.host) == ["db2", "db3"])
        #expect(configuration.additionalHosts.map(\.port) == [5432, 6432])
        #expect(configuration.targetSessionAttributes == .primary)
    }

    // MARK: Test with several servers (TS1)

    @Test func theTestNamesTheServerAConnectWouldUse() {
        #expect(PostgresConnectionTest.chosenIndex([.primary, .standby], for: .standby) == 1)
        #expect(PostgresConnectionTest.chosenIndex([nil, .primary], for: .any) == 1)
        #expect(PostgresConnectionTest.chosenIndex([.primary, .primary], for: .preferStandby) == 0)
        #expect(PostgresConnectionTest.chosenIndex([.standby, nil], for: .primary) == nil)
    }

    @Test func serverNamesAreShortUnlessTheyClash() {
        let names = PostgresConnectionTest.displayNames([
            .init(host: "db1.corp.example.com", port: 5432), .init(host: "db2.corp.example.com", port: 5432),
        ])
        #expect(names == ["db1", "db2"])
        #expect(PostgresConnectionTest.displayNames([.init(host: "127.0.0.1", port: 5432), .init(host: "127.0.0.1", port: 5433)])
                == ["127.0.0.1:5432", "127.0.0.1:5433"])
    }

    @Test func theFooterChipNamesTheNewServer() {
        let move = ConnectionServerMove(from: "db1", to: "db2", role: "primary", date: Date())
        #expect(move.label == "db2 · primary")
        #expect(move.help.hasPrefix("Moved from db1 at "))
    }

    // MARK: Client certificates (KW1, KE1, PF2)

    @Test func aP12FileNeedsItsPasswordAndSaysSoAtTest() async throws {
        let bundle = FileManager.default.temporaryDirectory.appendingPathComponent("echo-test-\(UUID().uuidString).p12")
        try #require(Data(base64Encoded: Self.testBundle)).write(to: bundle)
        defer { try? FileManager.default.removeItem(at: bundle) }
        #expect(ClientCertificateFiles.isBundle(bundle.path))
        #expect(ClientCertificateFiles.keyNeedsPassword(certificatePath: bundle.path, keyPath: nil))

        var connection = SavedConnection(connectionName: "R", host: "127.0.0.1", port: 1, database: "app", username: "alice", tlsMode: .require,
                                         sslCertPath: bundle.path)
        connection.databaseType = .postgresql
        for (password, expected) in [(nil as String?, "Enter the password that protects the key."), ("wrong", "The key password is wrong.")] {
            do {
                _ = try await PostgresNIOFactory().connect(
                    to: connection, database: "app",
                    authentication: .init(username: "alice", password: "pw", sslKeyPassword: password), connectTimeoutSeconds: 2)
                Issue.record("the .p12 cannot be opened without its password")
            } catch {
                let result = PostgresConnectionTest.failed(error, connection: connection, elapsed: nil)
                #expect(result.keyPasswordIssue == expected, "\(error)")
            }
        }
    }

    /// A self-signed EC certificate and key for CN=echo-test, password correct-horse (AES-256).
    static let testBundle = "MIIEBAIBAzCCA7IGCSqGSIb3DQEHAaCCA6MEggOfMIIDmzCCAkoGCSqGSIb3DQEHBqCCAjswggI3AgEAMIICMAYJKoZIhvcNAQcBMF8GCSqGSIb3DQEFDTBSMDEGCSqGSIb3DQEFDDAkBBA+MX9IEoVBZssVI4iI8oniAgIIADAMBggqhkiG9w0CCQUAMB0GCWCGSAFlAwQBKgQQtHUO1A64McVEqp36huz2VICCAcDw9djsPlHRDg/o99Zvm0TomFnRLEuBZlVb76SiS/n/NJYnHxeLgYDR+V7s0/B6SqRlLYw3jEPPqY2Z/1LdTO+38Jy+BoIKYFYC9/wJysCBm+iRn1ICcnM+56GYQnudGY5h+hYFuWFsMhoT6Bq5iAvmNhDrBqStUah6EgTxqzbjCUJKDoXGfEjo1tlSmJPyDfwpUC0uPdT47XZitbWyv8YUwKYZqLkO3/1MtWze3l/HxZHCzBONtjJpTGJcJ+9nFyKed7B35VOEkpERdfSj2aJ6SMtNUF808gZsUi81nzLfn93bvKTHvCpnj/ocObgjiDF/HbS2ULEPlNUCho3t4W9/FxIe4m97sq/JDvVQ3GYBl3govBGm/aVLEKlfiZ0ydnZ+VyhMYnafpTKoC40/NL5o0ggsTkwNpWErvOcnl0fWRvx8wxcrV9ypx85e32SewmkWfjg8ytrA6a3nsxqiudiJqVOMH9GMxOdUHmT/4UVn0Bn8yiI/f/AlNbX2c78sEftCRJnZD7Q7S4XqHWILP5Q5vzEiGmxDWyANhs+IXrJL5U8s8mRNlAzpy7s4o3E96/9D+qzkHE4/+IvEOAxJIv7WMIIBSQYJKoZIhvcNAQcBoIIBOgSCATYwggEyMIIBLgYLKoZIhvcNAQwKAQKggfcwgfQwXwYJKoZIhvcNAQUNMFIwMQYJKoZIhvcNAQUMMCQEEDEVLb4edrM6vOXsmaWebbUCAggAMAwGCCqGSIb3DQIJBQAwHQYJYIZIAWUDBAEqBBBLTm/HFO0RNbQmGwP/PHlCBIGQDG1NDSZVgaLBStiY4lGeu7D0eAG+BQiB+NigAvmtr7HLGZYVEY8xPU+YCWNE7PGbYYzzK0SmvKaCpIv3lUXRf7QuEeDspMWUEBjnfj1ZXm3SdoacmfYwcxFSa2eIhPcazEYO/Y/r4K7abhdS6sojVLNvbgTPYbt+351buU6PyGJrLP4bBbr46rErSFhRzAq8MSUwIwYJKoZIhvcNAQkVMRYEFJVddfX6/Nz3BCjx2Taabou9TtQXMEkwMTANBglghkgBZQMEAgEFAAQgEQBTuAIVGb7GnM4F6qTgDD6+bBxcu4s1FIwrAGZNMPkEEMKuqoZpWnoLku+8WaO6xC4CAggA"
}
