import Foundation
import SQLiteNIO

extension SQLiteSession: ExecutionPlanProviding {
    func getEstimatedExecutionPlan(_ sql: String) async throws -> ExecutionPlanData {
        let connection = try requireConnection()
        let rows = try await connection.query("EXPLAIN QUERY PLAN \(sql)")
        let planNodes = parseSQLiteQueryPlan(rows)
        let textPlan = formatSQLiteTextPlan(rows)
        return planNodes
            .map { root in
                ExecutionPlanData(
                    statements: [
                        ExecutionPlanStatement(
                            statementText: sql,
                            statementType: "SELECT",
                            subtreeCost: nil,
                            estimatedRows: nil,
                            optimizationLevel: nil,
                            queryPlan: ExecutionPlanQueryPlan(
                                cachedPlanSize: nil,
                                compileTime: nil,
                                compileCPU: nil,
                                rootOperator: root,
                                missingIndexes: []
                            )
                        )
                    ],
                    xml: textPlan
                )
            }
            ?? ExecutionPlanData(statements: [], xml: textPlan)
    }

    func getActualExecutionPlan(_ sql: String) async throws -> (result: QueryResultSet, plan: ExecutionPlanData) {
        let plan = try await getEstimatedExecutionPlan(sql)
        let result = try await simpleQuery(sql)
        return (result: result, plan: plan)
    }

    // MARK: - Parsing

    private nonisolated func parseSQLiteQueryPlan(_ rows: [SQLiteRow]) -> ExecutionPlanNode? {
        struct RawNode {
            let id: Int
            let parent: Int
            let detail: String
        }

        var rawNodes: [RawNode] = []
        for row in rows {
            let id = row.column("id")?.integer ?? 0
            let parent = row.column("parent")?.integer ?? 0
            let detail = row.column("detail")?.string ?? ""
            rawNodes.append(RawNode(id: id, parent: parent, detail: detail))
        }

        guard !rawNodes.isEmpty else { return nil }

        func buildTree(parentID: Int, counter: inout Int) -> [ExecutionPlanNode] {
            let children = rawNodes.filter { $0.parent == parentID }
            return children.map { raw in
                let nodeID = counter
                counter += 1
                let childNodes = buildTree(parentID: raw.id, counter: &counter)

                let (physicalOp, logicalOp) = parseDetail(raw.detail)

                return ExecutionPlanNode(
                    id: nodeID,
                    physicalOp: physicalOp,
                    logicalOp: logicalOp,
                    estimateRows: nil,
                    estimateIO: nil,
                    estimateCPU: nil,
                    avgRowSize: nil,
                    totalSubtreeCost: nil,
                    isParallel: false,
                    estimatedExecutions: nil,
                    actualRows: nil,
                    actualExecutions: nil,
                    actualElapsedMs: nil,
                    actualCPUMs: nil,
                    children: childNodes,
                    outputColumns: [],
                    warnings: []
                )
            }
        }

        var counter = 0
        let topLevel = buildTree(parentID: 0, counter: &counter)

        if topLevel.count == 1 {
            return topLevel[0]
        }

        // Wrap multiple roots under a synthetic root
        return ExecutionPlanNode(
            id: counter,
            physicalOp: "QUERY PLAN",
            logicalOp: "QUERY PLAN",
            estimateRows: nil,
            estimateIO: nil,
            estimateCPU: nil,
            avgRowSize: nil,
            totalSubtreeCost: nil,
            isParallel: false,
            estimatedExecutions: nil,
            actualRows: nil,
            actualExecutions: nil,
            actualElapsedMs: nil,
            actualCPUMs: nil,
            children: topLevel,
            outputColumns: [],
            warnings: []
        )
    }

    private nonisolated func parseDetail(_ detail: String) -> (physicalOp: String, logicalOp: String) {
        // SQLite EXPLAIN QUERY PLAN detail examples:
        // "SCAN users"
        // "SEARCH users USING INDEX idx_users_email (email=?)"
        // "SEARCH users USING COVERING INDEX idx_users_email (email=?)"
        // "USE TEMP B-TREE FOR ORDER BY"
        // "CO-ROUTINE subquery"
        let trimmed = detail.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("SCAN") {
            let tableName = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
            return ("Table Scan", tableName)
        } else if trimmed.hasPrefix("SEARCH") {
            if trimmed.contains("USING COVERING INDEX") {
                return ("Covering Index Seek", trimmed)
            } else if trimmed.contains("USING INDEX") {
                return ("Index Seek", trimmed)
            } else if trimmed.contains("USING INTEGER PRIMARY KEY") {
                return ("Primary Key Lookup", trimmed)
            }
            return ("Search", trimmed)
        } else if trimmed.contains("TEMP B-TREE") {
            return ("Sort", trimmed)
        } else if trimmed.hasPrefix("CO-ROUTINE") || trimmed.hasPrefix("COROUTINE") {
            return ("Subquery", trimmed)
        } else if trimmed.hasPrefix("COMPOUND") {
            return ("Union", trimmed)
        } else if trimmed.hasPrefix("MULTI-INDEX") {
            return ("Multi-Index OR", trimmed)
        }
        return (trimmed, trimmed)
    }

    private nonisolated func formatSQLiteTextPlan(_ rows: [SQLiteRow]) -> String {
        var lines: [String] = ["QUERY PLAN"]
        for row in rows {
            let id = row.column("id")?.integer ?? 0
            let parent = row.column("parent")?.integer ?? 0
            let detail = row.column("detail")?.string ?? ""
            let indent = String(repeating: "  ", count: depthOf(id: id, parent: parent, rows: rows))
            lines.append("\(indent)|--\(detail)")
        }
        return lines.joined(separator: "\n")
    }

    private nonisolated func depthOf(id: Int, parent: Int, rows: [SQLiteRow]) -> Int {
        if parent == 0 { return 1 }
        for row in rows {
            let rowID = row.column("id")?.integer ?? 0
            if rowID == parent {
                let rowParent = row.column("parent")?.integer ?? 0
                return 1 + depthOf(id: rowID, parent: rowParent, rows: rows)
            }
        }
        return 1
    }
}
