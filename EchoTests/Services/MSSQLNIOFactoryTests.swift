import Testing
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
}
