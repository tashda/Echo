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

        try runQuery(
            label: "Current database",
            sql: "SET FMTONLY OFF; SELECT DB_NAME() AS name;",
            using: connection
        )

        try runQuery(
            label: "Accessible databases",
            sql: """
            SET FMTONLY OFF;
            SELECT name, state_desc, HAS_DBACCESS(name) AS has_access
            FROM sys.databases
            ORDER BY name;
            """,
            using: connection
        )

        try runQuery(
            label: "Schemas in current database",
            sql: """
            SET FMTONLY OFF;
            SELECT name
            FROM sys.schemas
            ORDER BY name;
            """,
            using: connection
        )
    }

    private static func runQuery(label: String, sql: String, using connection: TDSConnection) throws {
        let logger = Logger(label: "MSSQLProbe")
        logger.info("Running probe: \(label)")
        let rows = try connection.rawSql(sql).wait()
        if rows.isEmpty {
            print("=== \(label) ===")
            print("(no rows)")
            return
        }

        let header = rows.first?.columnMetadata.colData.map { $0.colName } ?? []
        print("=== \(label) ===")
        print(header.joined(separator: "\t"))
        for row in rows {
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
