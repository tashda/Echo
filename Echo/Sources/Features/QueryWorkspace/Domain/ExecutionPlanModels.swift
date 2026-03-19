import Foundation

/// Database-agnostic execution plan data for display in Echo.
struct ExecutionPlanData: Sendable {
    let statements: [ExecutionPlanStatement]
    let xml: String?

    var rootOperator: ExecutionPlanNode? {
        statements.first?.queryPlan?.rootOperator
    }

    var missingIndexes: [ExecutionPlanMissingIndex] {
        statements.flatMap { $0.queryPlan?.missingIndexes ?? [] }
    }
}

struct ExecutionPlanStatement: Sendable {
    let statementText: String
    let statementType: String
    let subtreeCost: Double?
    let estimatedRows: Double?
    let optimizationLevel: String?
    let queryPlan: ExecutionPlanQueryPlan?
}

struct ExecutionPlanQueryPlan: Sendable {
    let cachedPlanSize: Int?
    let compileTime: Int?
    let compileCPU: Int?
    let rootOperator: ExecutionPlanNode?
    let missingIndexes: [ExecutionPlanMissingIndex]
}

struct ExecutionPlanNode: Sendable, Identifiable {
    let id: Int
    let physicalOp: String
    let logicalOp: String
    let estimateRows: Double?
    let estimateIO: Double?
    let estimateCPU: Double?
    let avgRowSize: Int?
    let totalSubtreeCost: Double?
    let isParallel: Bool
    let estimatedExecutions: Double?
    let actualRows: Int?
    let actualExecutions: Int?
    let actualElapsedMs: Int?
    let actualCPUMs: Int?
    let children: [ExecutionPlanNode]
    let outputColumns: [String]
    let warnings: [String]

    var operatorCost: Double? {
        guard let subtree = totalSubtreeCost else { return nil }
        let childCost = children.compactMap(\.totalSubtreeCost).reduce(0, +)
        return max(subtree - childCost, 0)
    }

    var costPercentage: Double? {
        operatorCost
    }
}

struct ExecutionPlanMissingIndex: Sendable, Identifiable {
    let id = UUID()
    let impact: Double?
    let database: String?
    let schema: String?
    let table: String?
    let equalityColumns: [String]
    let inequalityColumns: [String]
    let includeColumns: [String]

    var createStatement: String {
        var parts = ["CREATE INDEX [IX_\(table ?? "unknown")_"]
        let keyCols = equalityColumns + inequalityColumns
        parts.append(keyCols.joined(separator: "_"))
        parts.append("] ON ")
        if let schema, let table {
            parts.append("[\(schema)].[\(table)]")
        } else if let table {
            parts.append("[\(table)]")
        }
        parts.append(" (")
        parts.append(keyCols.map { "[\($0)]" }.joined(separator: ", "))
        parts.append(")")
        if !includeColumns.isEmpty {
            parts.append(" INCLUDE (")
            parts.append(includeColumns.map { "[\($0)]" }.joined(separator: ", "))
            parts.append(")")
        }
        return parts.joined()
    }
}
