import Foundation
import NIO
import SQLServerKit
import Logging

struct MSSQLNIOFactory: DatabaseFactory {
    private let logger = Logger(label: "dk.tippr.echo.mssql")

    func connect(
        host: String,
        port: Int,
        database: String?,
        tls: Bool,
        authentication: DatabaseAuthenticationConfiguration
    ) async throws -> DatabaseSession {
        let resolvedDatabase = database?.trimmingCharacters(in: .whitespacesAndNewlines)
        let loginDatabase = resolvedDatabase?.isEmpty == false ? resolvedDatabase! : "master"
        let metadataTimeout: TimeInterval = 30
        let metadataConfiguration = SQLServerMetadataClient.Configuration(
            includeSystemSchemas: false,
            enableColumnCache: true,
            includeRoutineDefinitions: false,
            includeTriggerDefinitions: true,
            commandTimeout: metadataTimeout,
            extractParameterDefaults: false,
            preferStoredProcedureColumns: false
        )
        // Convert Echo authentication to SQLServerKit authentication
        let sqlServerAuth: TDSAuthentication

        switch authentication.method {
        case .sqlPassword:
            guard let password = authentication.password else {
                throw DatabaseError.authenticationFailed("Password is required for SQL authentication")
            }
            sqlServerAuth = TDSAuthentication.sqlPassword(
                username: authentication.username,
                password: password
            )
        default:
            throw DatabaseError.authenticationFailed("Only SQL password authentication is supported for SQL Server")
        }

        let configuration = SQLServerClient.Configuration(
            hostname: host,
            port: port,
            login: .init(database: loginDatabase, authentication: sqlServerAuth),
            tlsConfiguration: tls ? .makeClientConfiguration() : nil,
            metadataConfiguration: metadataConfiguration
        )

        logger.info("Connecting to SQL Server at \(host):\(port)/\(loginDatabase)")

        // SQLServerClient.connect returns an EventLoopFuture, so we need to await it properly
        let client = try await withCheckedThrowingContinuation { continuation in
            SQLServerClient.connect(
                configuration: configuration,
                eventLoopGroupProvider: .shared(EchoEventLoopGroup.shared)
            ).whenComplete { result in
                switch result {
                case .success(let client):
                    continuation.resume(returning: client)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }

        // Wrap the SQLServerClient in an adapter that conforms to DatabaseSession
        return SQLServerSessionAdapter(
            client: client,
            database: resolvedDatabase?.isEmpty == false ? resolvedDatabase : nil
        )
    }
}
