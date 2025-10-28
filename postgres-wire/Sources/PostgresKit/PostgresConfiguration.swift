import Foundation
import Logging

public struct PostgresPoolConfiguration: Sendable {
    public var minimum: Int
    public var maximum: Int
    public var idleTimeoutSeconds: Int

    public init(minimum: Int = 0, maximum: Int = 8, idleTimeoutSeconds: Int = 30) {
        self.minimum = minimum
        self.maximum = maximum
        self.idleTimeoutSeconds = idleTimeoutSeconds
    }
}

public struct PostgresConfiguration: Sendable {
    public var host: String
    public var port: Int
    public var database: String
    public var username: String
    public var password: String?
    public var useTLS: Bool
    public var applicationName: String?
    public var pool: PostgresPoolConfiguration

    public init(
        host: String,
        port: Int = 5432,
        database: String = "postgres",
        username: String,
        password: String?,
        useTLS: Bool = false,
        applicationName: String? = nil,
        pool: PostgresPoolConfiguration = .init()
    ) {
        self.host = host
        self.port = port
        self.database = database
        self.username = username
        self.password = password
        self.useTLS = useTLS
        self.applicationName = applicationName
        self.pool = pool
    }
}

extension PostgresConfiguration {
    public func makeWireConfiguration() -> PostgresWireConfiguration {
        .init(
            host: host,
            port: port,
            username: username,
            password: password,
            database: database,
            useTLS: useTLS,
            applicationName: applicationName
        )
    }
}

