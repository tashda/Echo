import MySQLKit

enum MySQLPerformanceReportKind: String, CaseIterable, Identifiable {
    case unusedIndexes
    case schemaIndexStatistics
    case schemaTableStatistics
    case memoryGlobalByCurrentBytes
    case hostSummary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unusedIndexes:
            return "Unused Indexes"
        case .schemaIndexStatistics:
            return "Schema Index Statistics"
        case .schemaTableStatistics:
            return "Schema Table Statistics"
        case .memoryGlobalByCurrentBytes:
            return "Top Memory"
        case .hostSummary:
            return "Host Summary"
        }
    }

    func load(using performance: MySQLPerformanceClient) async throws -> MySQLPerformanceReport {
        switch self {
        case .unusedIndexes:
            return try await performance.unusedIndexes()
        case .schemaIndexStatistics:
            return try await performance.schemaIndexStatistics()
        case .schemaTableStatistics:
            return try await performance.schemaTableStatistics()
        case .memoryGlobalByCurrentBytes:
            return try await performance.memoryGlobalByCurrentBytes()
        case .hostSummary:
            return try await performance.hostSummary()
        }
    }
}
