import Testing
import SQLServerKit
@testable import Echo

struct MSSQLNIOFactoryTests {
    @Test func clientConfigurationPropagatesConnectTimeout() throws {
        let configuration = try MSSQLNIOFactory.makeClientConfiguration(
            host: "127.0.0.1",
            port: 1433,
            database: "master",
            tls: false,
            trustServerCertificate: true,
            sslRootCertPath: nil,
            mssqlEncryptionMode: .optional,
            hostNameInCertificate: nil,
            readOnlyIntent: false,
            authentication: .init(
                method: .sqlPassword,
                username: "sa",
                password: "Password123!"
            ),
            connectTimeoutSeconds: 27
        )

        #expect(configuration.connection.connectTimeoutSeconds == 27)
    }

    @Test func dedicatedConnectionConfigurationPropagatesConnectTimeout() throws {
        let configuration = try MSSQLNIOFactory.makeConnectionConfiguration(
            host: "127.0.0.1",
            port: 1433,
            database: "master",
            tls: false,
            trustServerCertificate: true,
            sslRootCertPath: nil,
            mssqlEncryptionMode: .optional,
            hostNameInCertificate: nil,
            readOnlyIntent: false,
            authentication: .init(
                method: .sqlPassword,
                username: "sa",
                password: "Password123!"
            ),
            connectTimeoutSeconds: 27
        )

        #expect(configuration.connectTimeoutSeconds == 27)
    }

    @Test func clientConfigurationCarriesRound22Settings() throws {
        let configuration = try MSSQLNIOFactory.makeClientConfiguration(
            host: "sql01", port: 1433, database: "Sales", tls: true, trustServerCertificate: false,
            sslRootCertPath: nil, mssqlEncryptionMode: .mandatory, hostNameInCertificate: nil,
            readOnlyIntent: false, allowLegacyTLS: true,
            authentication: .init(method: .sqlPassword, username: "sa", password: "Password123!")
        )
        #expect(configuration.connection.applicationName == "Echo")
        #expect(configuration.connection.allowLegacyTLS)
        #expect(configuration.connection.encryptionMode == .mandatory)
        #expect(configuration.connection.tlsConfiguration?.certificateVerification == .fullVerification)
    }

    @Test func connectionTestFixFollowsTheFailedCheck() {
        func failure(_ kind: SQLServerTLSFailure.Kind, names: [String] = ["sql01.contoso.com"], message: String = "") -> SQLServerError {
            let certificate = SQLServerCertificateSummary(
                subject: names.first ?? "", issuer: "Contoso CA", names: names,
                notValidBefore: .distantPast, notValidAfter: .distantFuture,
                isSelfSigned: false, sha256Fingerprint: "AA")
            return .tlsFailed(SQLServerTLSFailure(kind: kind, message: message, expectedHost: "10.0.0.5", certificate: certificate))
        }
        #expect(MSSQLConnectionTestFix.fix(for: failure(.certificateNameMismatch), encryptionMode: .mandatory)
                == .hostNameInCertificate("sql01.contoso.com"))
        #expect(MSSQLConnectionTestFix.fix(for: failure(.certificateSelfSigned), encryptionMode: .mandatory) == .trustCertificate)
        #expect(MSSQLConnectionTestFix.fix(for: failure(.certificateUntrusted), encryptionMode: .strict) == nil,
                "Strict always checks the certificate")
        #expect(MSSQLConnectionTestFix.fix(for: failure(.protocolVersionTooOld, message: "does not offer TLS 1.2"), encryptionMode: .optional)
                == .allowLegacyTLS)
        #expect(MSSQLConnectionTestFix.fix(for: SQLServerError.connectionClosed, encryptionMode: .mandatory) == nil)
    }
}
