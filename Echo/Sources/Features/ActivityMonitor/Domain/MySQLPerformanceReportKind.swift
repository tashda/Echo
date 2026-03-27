import MySQLKit

enum MySQLPerformanceReportKind: String, CaseIterable, Identifiable {
    case statementAnalysis
    case topRuntimeStatements
    case fullTableScans
    case unusedIndexes
    case schemaIndexStatistics
    case schemaTableStatistics
    case waitsGlobalByLatency
    case waitsByUserByLatency
    case hostSummary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .statementAnalysis:
            return "Statement Analysis"
        case .topRuntimeStatements:
            return "Top Runtime Statements"
        case .fullTableScans:
            return "Full Table Scans"
        case .unusedIndexes:
            return "Unused Indexes"
        case .schemaIndexStatistics:
            return "Schema Index Statistics"
        case .schemaTableStatistics:
            return "Schema Table Statistics"
        case .waitsGlobalByLatency:
            return "Global Waits"
        case .waitsByUserByLatency:
            return "Waits by User"
        case .hostSummary:
            return "Host Summary"
        }
    }

    func load(using performance: MySQLPerformanceClient) async throws -> MySQLPerformanceReport {
        switch self {
        case .statementAnalysis:
            return try await performance.statementAnalysis()
        case .topRuntimeStatements:
            return try await performance.topRuntimeStatements()
        case .fullTableScans:
            return try await performance.fullTableScans()
        case .unusedIndexes:
            return try await performance.unusedIndexes()
        case .schemaIndexStatistics:
            return try await performance.schemaIndexStatistics()
        case .schemaTableStatistics:
            return try await performance.schemaTableStatistics()
        case .waitsGlobalByLatency:
            return try await performance.waitsGlobalByLatency()
        case .waitsByUserByLatency:
            return try await performance.waitsByUserByLatency()
        case .hostSummary:
            return try await performance.hostSummary()
        }
    }
}
