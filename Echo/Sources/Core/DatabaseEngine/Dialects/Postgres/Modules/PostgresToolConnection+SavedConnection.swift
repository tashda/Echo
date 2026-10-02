import Foundation
import PostgresKit

extension PostgresToolConnection {
    /// How the bundled tools reach `connection`'s server for `database`, exactly as the connection
    /// does (#34): hosts, TLS mode and files, Kerberos; the password only in the environment.
    static func make(
        for connection: SavedConnection,
        database: String?,
        authentication: DatabaseAuthenticationConfiguration
    ) async throws -> PostgresToolConnection {
        try await PostgresNIOFactory.makeConfiguration(
            for: connection, database: database, authentication: authentication, connectTimeoutSeconds: 15
        ).toolConnection()
    }
}
