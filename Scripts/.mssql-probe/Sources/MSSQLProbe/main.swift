import Foundation
import Logging
import NIOCore
import NIOPosix
import NIOSSL
import TDS

struct Config {
    let host: String
    let port: Int
    let username: String
    let password: String
    let database: String?
    let enableTLS: Bool

    static func load() throws -> Config {
        let env = ProcessInfo.processInfo.environment

        guard let host = env["MSSQL_HOST"], !host.isEmpty else {
            throw ConfigError.missing("MSSQL_HOST")
        }

        let portString = env["MSSQL_PORT"] ?? "1433"
        guard let port = Int(portString) else {
            throw ConfigError.invalid("MSSQL_PORT", portString)
        }

        guard let username = env["MSSQL_USERNAME"], !username.isEmpty else {
            throw ConfigError.missing("MSSQL_USERNAME")
        }

        guard let password = env["MSSQL_PASSWORD"], !password.isEmpty else {
            throw ConfigError.missing("MSSQL_PASSWORD")
        }

        let database = env["MSSQL_DATABASE"].flatMap { $0.isEmpty ? nil : $0 }
        let enableTLS = (env["MSSQL_ENABLE_TLS"] ?? "false").lowercased() == "true"

        return Config(
            host: host,
            port: port,
            username: username,
            password: password,
            database: database,
            enableTLS: enableTLS
        )
    }
}

enum ConfigError: Error, CustomStringConvertible {
    case missing(String)
    case invalid(String, String)

    var description: String {
        switch self {
        case .missing(let key):
            return "Missing required environment variable \(key)"
        case .invalid(let key, let value):
            return "Invalid value '\(value)' provided for \(key)"
        }
    }
}

@main
struct Main {
    static func main() throws {
        LoggingSystem.bootstrap(StreamLogHandler.standardOutput)
        let config = try Config.load()
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            do {
                try group.syncShutdownGracefully()
            } catch {
                Logger(label: "MSSQLProbe").warning("Failed to shutdown event loop group: \(error)")
            }
        }

        let logger = Logger(label: "MSSQLProbe")

        let loginDatabase = config.database ?? ""
        let tlsConfiguration = config.enableTLS ? TLSConfiguration.makeClientConfiguration() : nil
        let connectionConfiguration = SQLServerConnection.Configuration(
            hostname: config.host,
            port: config.port,
            login: .init(
                database: loginDatabase,
                authentication: .sqlPassword(username: config.username, password: config.password)
            ),
            tlsConfiguration: tlsConfiguration
        )

        let connection = try SQLServerConnection.connect(
            configuration: connectionConfiguration,
            on: group.any(),
            logger: logger
        ).wait()
        defer {
            do {
                try connection.close().wait()
            } catch {
                logger.warning("Failed to close connection: \(error)")
            }
        }

        logger.info("Connected and logged in to \(config.host):\(config.port) (login database: \(loginDatabase.isEmpty ? "<default>" : loginDatabase))")

        try sessionReset(label: "Initial reset", on: connection)

        let resolvedDatabase = try resolveCurrentDatabase(using: connection, fallback: loginDatabase)
        var expectedDatabases: [String] = ["AdventureWorks2022", "master"]
        if !expectedDatabases.contains(where: { $0.caseInsensitiveCompare(resolvedDatabase) == .orderedSame }) {
            expectedDatabases.append(resolvedDatabase)
        }

        let probes: [Probe] = [
            Probe(
                label: "Current database",
                sql: "SELECT DB_NAME() AS name;",
                minimumExpectedRows: 1,
                expectedContains: [resolvedDatabase],
                expectedColumn: "name"
            ),
            Probe(
                label: "Accessible databases",
                sql: """
                SELECT name, state_desc, HAS_DBACCESS(name) AS has_access
                FROM sys.databases
                ORDER BY name;
                """,
                minimumExpectedRows: 2,
                expectedContains: expectedDatabases,
                expectedColumn: "name"
            ),
            Probe(
                label: "sys.databases (no HAS_DBACCESS)",
                sql: """
                SELECT name, state_desc
                FROM sys.databases
                ORDER BY name;
                """,
                minimumExpectedRows: 2,
                expectedContains: expectedDatabases,
                expectedColumn: "name"
            ),
            Probe(
                label: "sp_databases",
                sql: """
                EXEC master.dbo.sp_databases;
                """,
                minimumExpectedRows: 2,
                expectedContains: expectedDatabases,
                expectedColumn: "DATABASE_NAME"
            ),
            Probe(
                label: "Schemas in current database",
                sql: """
                SELECT name
                FROM sys.schemas
                ORDER BY name;
                """,
                minimumExpectedRows: 1,
                expectedContains: ["dbo"],
                expectedColumn: "name"
            ),
            Probe(
                label: "INFORMATION_SCHEMA schemas",
                sql: """
                SELECT schema_name AS name
                FROM INFORMATION_SCHEMA.SCHEMATA
                ORDER BY name;
                """,
                minimumExpectedRows: 1,
                expectedContains: ["INFORMATION_SCHEMA"],
                expectedColumn: "name"
            ),
            Probe(
                label: "Sys tables sample",
                sql: """
                SELECT TOP 5 name, object_id
                FROM sys.tables
                ORDER BY name;
                """
            ),
            Probe(
                label: "sp_describe_first_result_set (sys.databases)",
                sql: """
                EXEC sp_describe_first_result_set N'SELECT name FROM sys.databases';
                """
            ),
            Probe(
                label: "Post-describe reset check",
                sql: "SELECT name FROM sys.databases ORDER BY name;",
                minimumExpectedRows: 2,
                expectedContains: expectedDatabases,
                expectedColumn: "name"
            ),
            Probe(
                label: "dbo column metadata",
                sql: """
                SELECT
                    t.name AS table_name,
                    c.name AS column_name,
                    ty.name AS data_type,
                    c.is_nullable,
                    c.max_length AS character_maximum_length,
                    c.precision AS numeric_precision,
                    c.scale AS numeric_scale,
                    c.is_identity,
                    c.is_computed,
                    c.column_id AS ordinal_position
                FROM sys.columns AS c
                JOIN sys.tables AS t ON c.object_id = t.object_id
                JOIN sys.schemas AS s ON t.schema_id = s.schema_id
                JOIN sys.types AS ty ON c.user_type_id = ty.user_type_id
                WHERE s.name = N'dbo'
                ORDER BY t.name, c.column_id;
                """,
                minimumExpectedRows: 1,
                expectedContains: ["AWBuildVersion"],
                expectedColumn: "table_name"
            )
        ]

        try runSeries(probes, using: connection)
        try metadataSmokeTest(using: connection)
    }

    private struct Probe {
        let label: String
        let sql: String
        let minimumExpectedRows: Int?
        let expectedContains: [String]
        let expectedColumn: String?

        init(
            label: String,
            sql: String,
            minimumExpectedRows: Int? = nil,
            expectedContains: [String] = [],
            expectedColumn: String? = nil
        ) {
            self.label = label
            self.sql = sql
            self.minimumExpectedRows = minimumExpectedRows
            self.expectedContains = expectedContains
            self.expectedColumn = expectedColumn
        }
    }

    private struct ProbeExpectationError: Error, CustomStringConvertible {
        let message: String

        var description: String { message }
    }

    private static func runSeries(_ probes: [Probe], using connection: SQLServerConnection) throws {
        let logger = Logger(label: "MSSQLProbe")

        for probe in probes {
            logger.info("Running probe: \(probe.label)")
            let start = DispatchTime.now()
            do {
                let rows = try connection.query(probe.sql).wait()
                try validate(probe: probe, rows: rows)
                let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000.0
                report(probe: probe, rows: rows, elapsed: elapsed, logger: logger)
            } catch {
                logger.error("Probe '\(probe.label)' failed: \(error)")
                throw error
            }
            try sessionReset(label: "Post \(probe.label)", on: connection)
        }
    }

    private static func validate(probe: Probe, rows: [TDSRow]) throws {
        if let minimum = probe.minimumExpectedRows, rows.count < minimum {
            throw ProbeExpectationError(message: "\(probe.label) expected at least \(minimum) row(s) but received \(rows.count)")
        }

        guard !probe.expectedContains.isEmpty else { return }

        let header = rows.first?.columnMetadata.colData.map { $0.colName } ?? []
        let columnName: String
        if let explicit = probe.expectedColumn, !explicit.isEmpty {
            columnName = explicit
        } else if let inferred = header.first, !inferred.isEmpty {
            columnName = inferred
        } else {
            throw ProbeExpectationError(message: "\(probe.label) could not determine a column for expectation checks")
        }

        let normalizedValues = Set(
            rows.compactMap { row -> String? in
                guard let data = row.column(columnName) else { return nil }
                if let stringValue = data.string {
                    return stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                }
                return data.description.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
        )

        for expected in probe.expectedContains {
            let normalizedExpected = expected.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !normalizedValues.contains(normalizedExpected) {
                throw ProbeExpectationError(message: "\(probe.label) missing expected value '\(expected)' in column \(columnName)")
            }
        }
    }

    private static func report(
        probe: Probe,
        rows: [TDSRow],
        elapsed: Double,
        logger: Logger
    ) {
        let header = rows.first?.columnMetadata.colData.map { $0.colName } ?? []
        let status = "rows=\(rows.count)"
        print("=== \(probe.label) [\(status), \(String(format: "%.2f ms", elapsed))] ===")
        if header.isEmpty {
            print("(no columns)")
        } else {
            print(header.joined(separator: "	"))
        }
        if rows.isEmpty {
            print("(no rows)")
            return
        }
        for row in rows.prefix(25) {
            let values = header.map { columnName -> String in
                guard let data = row.column(columnName) else {
                    return "NULL"
                }
                if let stringValue = data.string {
                    return stringValue
                }
                return data.description
            }
            print(values.joined(separator: "	"))
        }
        if rows.count > 25 {
            print("… (\(rows.count - 25) more rows)")
        }
    }

    private static func sessionReset(label: String, on connection: SQLServerConnection) throws {
        let logger = Logger(label: "MSSQLProbe")
        logger.debug("Applying session defaults (\(label))")
        _ = try connection.query("SET FMTONLY OFF;").wait()

        logger.debug("Probing @@OPTIONS after \(label)")
        if let rows = try? connection.query("SELECT @@OPTIONS & 2 AS fmtOnlyFlag;").wait(),
           let value = rows.first?.column("fmtOnlyFlag")?.int32 {
            logger.info("@@OPTIONS FMTONLY flag = \(value)")
        }
    }

    private static func resolveCurrentDatabase(using connection: SQLServerConnection, fallback: String) throws -> String {
        if let row = try connection.query("SELECT DB_NAME() AS name;").wait().first,
           let name = row.column("name")?.string,
           !name.isEmpty {
            return name
        }
        return fallback.isEmpty ? "master" : fallback
    }

    private static func metadataSmokeTest(using connection: SQLServerConnection) throws {
        let logger = Logger(label: "MSSQLProbe")
        logger.info("Running metadata smoke test via SQLServerConnection.listColumns(dbo.AWBuildVersion)")
        let columns = try connection.listColumns(schema: "dbo", table: "AWBuildVersion").wait()
        guard !columns.isEmpty else {
            throw ProbeExpectationError(message: "listColumns returned 0 columns for dbo.AWBuildVersion")
        }
        logger.info("Metadata smoke test returned \(columns.count) columns for dbo.AWBuildVersion")
    }
}
