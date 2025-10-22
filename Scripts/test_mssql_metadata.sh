#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/mssql.env"
TDS_PATH="/Users/k/Development/tds-nio"

if [[ ! -f "${ENV_FILE}" ]]; then
  cat <<EOF >&2
[mssql-metadata] Missing environment file at ${ENV_FILE}
Copy mssql.env.example to mssql.env and fill in your SQL Server credentials.
EOF
  exit 2
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

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

WORK_DIR="${ROOT_DIR}/Scripts/.mssql-probe"
mkdir -p "${WORK_DIR}/Sources/MSSQLProbe"
MODULE_CACHE="${WORK_DIR}/.module-cache"
SWIFT_CACHE="${WORK_DIR}/.build-cache"
mkdir -p "${MODULE_CACHE}"
mkdir -p "${SWIFT_CACHE}"

# Clear previous probe directory to avoid stale Package.swift manifests or build artifacts
rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}/Sources/MSSQLProbe"
MODULE_CACHE="${WORK_DIR}/.module-cache"
mkdir -p "${MODULE_CACHE}"

# Regenerate package manifest on each run so dependency path stays up to date.
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

        let loginDatabase = targetDatabase.isEmpty ? "master" : targetDatabase
        var expectedDatabases: [String] = ["AdventureWorks2022", "master"]
        if !expectedDatabases.contains(where: { $0.caseInsensitiveCompare(loginDatabase) == .orderedSame }) {
            expectedDatabases.append(loginDatabase)
        }

        let tests: [Probe] = [
            Probe(
                label: "Current database",
                sql: "SET FMTONLY OFF; SELECT DB_NAME() AS name;",
                minimumExpectedRows: 1,
                expectedContains: [loginDatabase],
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
                    c.TABLE_NAME,
                    c.COLUMN_NAME,
                    c.DATA_TYPE,
                    c.IS_NULLABLE,
                    c.CHARACTER_MAXIMUM_LENGTH,
                    c.NUMERIC_PRECISION,
                    c.NUMERIC_SCALE,
                    COLUMNPROPERTY(object_id(c.TABLE_SCHEMA + '.' + c.TABLE_NAME), c.COLUMN_NAME, 'IsIdentity') AS is_identity,
                    COLUMNPROPERTY(object_id(c.TABLE_SCHEMA + '.' + c.TABLE_NAME), c.COLUMN_NAME, 'IsComputed') AS is_computed,
                    c.ORDINAL_POSITION
                FROM INFORMATION_SCHEMA.COLUMNS AS c
                WHERE c.TABLE_SCHEMA = 'dbo'
                ORDER BY c.TABLE_NAME, c.ORDINAL_POSITION;
                """,
                minimumExpectedRows: 1,
                expectedContains: ["AWBuildVersion"],
                expectedColumn: "TABLE_NAME"
            )
        ]

        try runSeries(tests, using: connection)
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

    private static func runSeries(_ probes: [Probe], using connection: TDSConnection) throws {
        let logger = Logger(label: "MSSQLProbe")

        for probe in probes {
            logger.info("Running probe: \(probe.label)")
            let start = DispatchTime.now()
            do {
                let effectiveSQL: String
                if probe.sql.trimmingCharacters(in: .whitespacesAndNewlines)
                    .uppercased()
                    .hasPrefix("SET FMTONLY OFF") {
                    effectiveSQL = probe.sql
                } else {
                    effectiveSQL = "SET FMTONLY OFF;\n\(probe.sql)"
                }
                let rows = try connection.rawSql(effectiveSQL).wait()
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
            print(header.joined(separator: "\t"))
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
            print(values.joined(separator: "\t"))
        }
        if rows.count > 25 {
            print("… (\(rows.count - 25) more rows)")
        }
    }

    private static func sessionReset(label: String, on connection: TDSConnection) throws {
        let logger = Logger(label: "MSSQLProbe")
        logger.debug("Applying session defaults (\(label))")
        _ = try connection.rawSql("SET FMTONLY OFF;").wait()

        logger.debug("Probing @@OPTIONS after \(label)")
        if let rows = try? connection.rawSql("SELECT @@OPTIONS & 2 AS fmtOnlyFlag;").wait(),
           let value = rows.first?.column("fmtOnlyFlag")?.int32 {
            logger.info("@@OPTIONS FMTONLY flag = \(value)")
        }
    }
}
EOF

echo "[mssql-metadata] Building probe (incremental) …" >&2
echo "[mssql-metadata] Using TDS package at ${TDS_PATH}" >&2
ls -lh "${TDS_PATH}/.build/debug" 2>/dev/null >&2

env \
    HOME="${WORK_DIR}" \
    MSSQL_HOST="${MSSQL_HOST}" \
    MSSQL_PORT="${MSSQL_PORT}" \
    MSSQL_USERNAME="${MSSQL_USERNAME}" \
    MSSQL_PASSWORD="${MSSQL_PASSWORD}" \
    MSSQL_DATABASE="${MSSQL_DATABASE}" \
    MSSQL_ENABLE_TLS="${MSSQL_ENABLE_TLS}" \
    LOG_LEVEL="${LOG_LEVEL:-info}" \
    CLANG_MODULE_CACHE_PATH="${MODULE_CACHE}" \
    SWIFT_MODULE_DIRECTORY="${MODULE_CACHE}" \
    swift build \
        --package-path "${WORK_DIR}" \
        --configuration debug \
        --product mssql-probe \
        --cache-path "${SWIFT_CACHE}" \
        --disable-sandbox \
        >/tmp/mssql-probe-build.log 2>&1 || {
        status=$?
        echo "[mssql-metadata] swift build failed (exit ${status}). Build log:" >&2
        cat /tmp/mssql-probe-build.log >&2
        exit "${status}"
    }

set +e
output="$(env \
    HOME="${WORK_DIR}" \
    MSSQL_HOST="${MSSQL_HOST}" \
    MSSQL_PORT="${MSSQL_PORT}" \
    MSSQL_USERNAME="${MSSQL_USERNAME}" \
    MSSQL_PASSWORD="${MSSQL_PASSWORD}" \
    MSSQL_DATABASE="${MSSQL_DATABASE}" \
    MSSQL_ENABLE_TLS="${MSSQL_ENABLE_TLS}" \
    LOG_LEVEL="${LOG_LEVEL:-info}" \
    CLANG_MODULE_CACHE_PATH="${MODULE_CACHE}" \
    SWIFT_MODULE_DIRECTORY="${MODULE_CACHE}" \
    "${WORK_DIR}/.build/debug/mssql-probe" "$@" 2>&1)"
status=$?
set -e

printf '%s\n' "${output}"

if [[ ${status} -ne 0 ]]; then
  echo "[mssql-metadata] Probe failed with exit code ${status}" >&2
else
  echo "[mssql-metadata] Probe completed successfully."
fi

exit "${status}"
