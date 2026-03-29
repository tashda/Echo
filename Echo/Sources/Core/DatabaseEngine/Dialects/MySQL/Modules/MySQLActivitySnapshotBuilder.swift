import Foundation
import MySQLKit

public struct MySQLActivityOverview: Sendable {
    let uptimeSeconds: Int?
    let currentConnections: Int
    let maxConnections: Int?
    let bytesReceivedPerSecond: Double?
    let bytesSentPerSecond: Double?
    let queriesPerSecond: Double?
    let slowQueries: Int?
    let openTables: Int?
    let tableOpenCache: Int?
    let bufferPoolUsagePercent: Double?
    let innodbReadsPerSecond: Double?
    let innodbWritesPerSecond: Double?
}

struct MySQLActivityStatusSample: Sendable {
    let capturedAt: Date
    let variables: [String: String]
}

enum MySQLActivitySnapshotBuilder {
    static func makeSnapshot(
        capturedAt: Date,
        processes: [MySQLProcess],
        statusVariables: [MySQLStatusVariable],
        globalVariables: [MySQLGlobalVariable],
        previousSample: MySQLActivityStatusSample?
    ) -> (snapshot: MySQLActivitySnapshot, sample: MySQLActivityStatusSample) {
        let statusLookup = Dictionary(
            uniqueKeysWithValues: statusVariables.map { ($0.name.lowercased(), $0.value) }
        )
        let globalLookup = Dictionary(
            uniqueKeysWithValues: globalVariables.map { ($0.name.lowercased(), $0.value) }
        )
        let sample = MySQLActivityStatusSample(capturedAt: capturedAt, variables: statusLookup)

        let overview = MySQLActivityOverview(
            uptimeSeconds: intValue("uptime", in: statusLookup),
            currentConnections: intValue("threads_connected", in: statusLookup) ?? processes.count,
            maxConnections: intValue("max_connections", in: globalLookup),
            bytesReceivedPerSecond: rate(
                variable: "bytes_received",
                current: statusLookup,
                previous: previousSample,
                capturedAt: capturedAt
            ),
            bytesSentPerSecond: rate(
                variable: "bytes_sent",
                current: statusLookup,
                previous: previousSample,
                capturedAt: capturedAt
            ),
            queriesPerSecond: rate(
                variable: "questions",
                current: statusLookup,
                previous: previousSample,
                capturedAt: capturedAt
            ),
            slowQueries: intValue("slow_queries", in: statusLookup),
            openTables: intValue("open_tables", in: statusLookup),
            tableOpenCache: intValue("table_open_cache", in: globalLookup),
            bufferPoolUsagePercent: bufferPoolUsagePercent(in: statusLookup),
            innodbReadsPerSecond: rate(
                variable: "innodb_data_reads",
                current: statusLookup,
                previous: previousSample,
                capturedAt: capturedAt
            ),
            innodbWritesPerSecond: rate(
                variable: "innodb_data_writes",
                current: statusLookup,
                previous: previousSample,
                capturedAt: capturedAt
            )
        )

        let snapshot = MySQLActivitySnapshot(
            capturedAt: capturedAt,
            processes: processes.map(makeProcessInfo),
            globalVariables: globalVariables.map(makeGlobalVariableInfo).sorted { $0.name < $1.name },
            overview: overview
        )
        return (snapshot, sample)
    }

    private static func makeProcessInfo(from process: MySQLProcess) -> MySQLProcessInfo {
        MySQLProcessInfo(
            id: Int(process.id),
            user: process.user,
            host: process.host ?? "",
            database: process.database,
            command: process.command,
            time: process.timeSeconds,
            state: process.state,
            info: process.info
        )
    }

    private static func makeGlobalVariableInfo(from variable: MySQLGlobalVariable) -> MySQLGlobalVariableInfo {
        MySQLGlobalVariableInfo(
            name: variable.name,
            value: variable.value,
            category: variableCategory(for: variable.name)
        )
    }

    private static func variableCategory(for variableName: String) -> String {
        let normalized = variableName.lowercased()
        if let prefix = normalized.split(separator: "_").first, !prefix.isEmpty {
            return prefix.uppercased()
        }
        return "GENERAL"
    }

    private static func bufferPoolUsagePercent(in variables: [String: String]) -> Double? {
        guard
            let usedPages = doubleValue("innodb_buffer_pool_pages_data", in: variables),
            let totalPages = doubleValue("innodb_buffer_pool_pages_total", in: variables),
            totalPages > 0
        else {
            return nil
        }
        return (usedPages / totalPages) * 100
    }

    private static func rate(
        variable: String,
        current: [String: String],
        previous: MySQLActivityStatusSample?,
        capturedAt: Date
    ) -> Double? {
        guard
            let previous,
            let currentValue = doubleValue(variable, in: current),
            let previousValue = doubleValue(variable, in: previous.variables)
        else {
            return nil
        }

        let elapsed = capturedAt.timeIntervalSince(previous.capturedAt)
        guard elapsed > 0 else { return nil }
        return max(0, currentValue - previousValue) / elapsed
    }

    private static func intValue(_ variable: String, in variables: [String: String]) -> Int? {
        variables[variable].flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private static func doubleValue(_ variable: String, in variables: [String: String]) -> Double? {
        variables[variable].flatMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }
}
