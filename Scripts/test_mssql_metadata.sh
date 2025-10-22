#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/mssql.env"
TDS_PATH="${ROOT_DIR}/../tds-nio"

if [[ ! -f "${ENV_FILE}" ]]; then
  cat <<EOF >&2
[mssql-metadata] Missing environment file at ${ENV_FILE}
Copy mssql.env.example to mssql.env and fill in your SQL Server credentials.
EOF
  exit 2
fi

# shellcheck disable=SC1090
source "${ENV_FILE}"

: "${MSSQL_HOST:?Set MSSQL_HOST in ${ENV_FILE}}"
: "${MSSQL_PORT:=1433}"
: "${MSSQL_USERNAME:?Set MSSQL_USERNAME in ${ENV_FILE}}"
: "${MSSQL_PASSWORD:?Set MSSQL_PASSWORD in ${ENV_FILE}}"
: "${MSSQL_DATABASE:=}"
: "${MSSQL_ENABLE_TLS:=false}"

if [[ ! -d "${TDS_PATH}" ]]; then
  cat <<EOF >&2
[mssql-metadata] Unable to find local tds-nio checkout at ${TDS_PATH}
Update Scripts/test_mssql_metadata.sh with the correct path.
EOF
  exit 3
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mssql-probe.XXXXXX")"
cleanup() {
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

cat >"${WORK_DIR}/Package.swift" <<EOF
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MSSQLProbe",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "mssql-probe", targets: ["MSSQLProbe"])
    ],
    dependencies: [
        .package(path: "${TDS_PATH}")
    ],
    targets: [
        .executableTarget(
            name: "MSSQLProbe",
            dependencies: [
                .product(name: "TDS", package: "tds-nio")
            ]
        )
    ]
)
EOF

mkdir -p "${WORK_DIR}/Sources/MSSQLProbe"

cat >"${WORK_DIR}/Sources/MSSQLProbe/main.swift" <<'EOF'
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

        let address = try SocketAddress.makeAddressResolvingHost(config.host, port: config.port)

        let tlsConfiguration: TLSConfiguration?
        let serverHostname: String?
        if config.enableTLS {
            tlsConfiguration = TLSConfiguration.makeClientConfiguration()
            serverHostname = config.host
        } else {
            tlsConfiguration = nil
            serverHostname = nil
        }

        let connection = try TDSConnection.connect(
            to: address,
            tlsConfiguration: tlsConfiguration,
            serverHostname: serverHostname,
            on: group.any()
        ).wait()
        defer {
            do {
                try connection.close().wait()
            } catch {
                logger.warning("Failed to close connection: \(error)")
            }
        }

        logger.info("Connected to \(config.host):\(config.port)")

        let targetDatabase = config.database ?? ""
        try connection.login(
            username: config.username,
            password: config.password,
            server: config.host,
            database: targetDatabase
        ).wait()

        logger.info("Login succeeded (database: \(targetDatabase.isEmpty ? "<default>" : targetDatabase))")

        try sessionReset(label: "Initial reset", on: connection)

        let tests: [Probe] = [
            Probe(
                label: "Current database",
                sql: "SET FMTONLY OFF; SELECT DB_NAME() AS name;"
            ),
            Probe(
                label: "Accessible databases",
                sql: """
                SET FMTONLY OFF;
                SELECT name, state_desc, HAS_DBACCESS(name) AS has_access
                FROM sys.databases
                ORDER BY name;
                """
            ),
            Probe(
                label: "sys.databases (no HAS_DBACCESS)",
                sql: """
                SET FMTONLY OFF;
                SELECT name, state_desc
                FROM sys.databases
                ORDER BY name;
                """
            ),
            Probe(
                label: "sp_databases",
                sql: """
                SET FMTONLY OFF;
                EXEC master.dbo.sp_databases;
                """
            ),
            Probe(
                label: "Schemas in current database",
                sql: """
                SET FMTONLY OFF;
                SELECT name
                FROM sys.schemas
                ORDER BY name;
                """
            ),
            Probe(
                label: "INFORMATION_SCHEMA schemas",
                sql: """
                SET FMTONLY OFF;
                SELECT schema_name AS name
                FROM INFORMATION_SCHEMA.SCHEMATA
                ORDER BY name;
                """
            ),
            Probe(
                label: "Sys tables sample",
                sql: """
                SET FMTONLY OFF;
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
                sql: "SET FMTONLY OFF; SELECT name FROM sys.databases ORDER BY name;"
            )
        ]

        try runSeries(tests, using: connection)
    }

    private struct Probe {
        let label: String
        let sql: String
        let expectRows: Bool?

        init(label: String, sql: String, expectRows: Bool? = nil) {
            self.label = label
            self.sql = sql
            self.expectRows = expectRows
        }
    }

    private static func runSeries(_ probes: [Probe], using connection: TDSConnection) throws {
        let logger = Logger(label: "MSSQLProbe")

        for probe in probes {
            logger.info("Running probe: \(probe.label)")
            let start = DispatchTime.now()
            do {
                let rows = try connection.rawSql(probe.sql).wait()
                let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000.0
                report(probe: probe, rows: rows, elapsed: elapsed, logger: logger)
            } catch {
                logger.error("Probe '\(probe.label)' failed: \(error)")
                throw error
            }
            try sessionReset(label: "Post \(probe.label)", on: connection)
        }
    }

    private static func report(
        probe: Probe,
        rows: [TDSRow],
        elapsed: Double,
        logger: Logger
    ) {
        if rows.isEmpty {
            print("=== \(probe.label) [rows=0, \(String(format: "%.2f ms", elapsed))] ===")
            print("(no rows)")
        } else {
            let header = rows.first?.columnMetadata.colData.map { $0.colName } ?? []
            print("=== \(probe.label) [rows=\(rows.count), \(String(format: "%.2f ms", elapsed))] ===")
            print(header.joined(separator: "\t"))
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
                print(values.joined(separator: "\t"))
            }
            if rows.count > 25 {
                print("… (\(rows.count - 25) more rows)")
            }
        }
    }

    private static func sessionReset(label: String, on connection: TDSConnection) throws {
        let logger = Logger(label: "MSSQLProbe")
        logger.debug("Applying session defaults (\(label))")
        _ = try connection.rawSql("SET FMTONLY OFF; SET NO_BROWSETABLE OFF;").wait()

        logger.debug("Probing @@OPTIONS after \(label)")
        if let rows = try? connection.rawSql("SELECT @@OPTIONS & 2 AS fmtOnlyFlag;").wait(),
           let value = rows.first?.column("fmtOnlyFlag")?.int32 {
            logger.info("@@OPTIONS FMTONLY flag = \(value)")
        }
    }
}
EOF

echo "[mssql-metadata] Building probe (this may take a moment)…" >&2

env \
    MSSQL_HOST="${MSSQL_HOST}" \
    MSSQL_PORT="${MSSQL_PORT}" \
    MSSQL_USERNAME="${MSSQL_USERNAME}" \
    MSSQL_PASSWORD="${MSSQL_PASSWORD}" \
    MSSQL_DATABASE="${MSSQL_DATABASE}" \
    MSSQL_ENABLE_TLS="${MSSQL_ENABLE_TLS}" \
    swift run --package-path "${WORK_DIR}" --configuration release mssql-probe "$@"
