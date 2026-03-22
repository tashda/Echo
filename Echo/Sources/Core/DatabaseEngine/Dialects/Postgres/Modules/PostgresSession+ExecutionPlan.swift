import Foundation
import PostgresKit

extension PostgresSession: ExecutionPlanProviding {
    func getEstimatedExecutionPlan(_ sql: String) async throws -> ExecutionPlanData {
        let lines = try await client.connection.explain(
            sql,
            verbose: true,
            format: .json
        )
        let jsonString = lines.joined(separator: "\n")
        let planData = try parsePostgresExplainJSON(jsonString, isAnalyze: false)

        // Also get the text plan for the raw view
        let textLines = try await client.connection.explain(
            sql,
            verbose: true
        )
        return ExecutionPlanData(
            statements: planData.statements,
            xml: textLines.joined(separator: "\n")
        )
    }

    func getActualExecutionPlan(_ sql: String) async throws -> (result: QueryResultSet, plan: ExecutionPlanData) {
        let lines = try await client.connection.explain(
            sql,
            analyze: true,
            verbose: true,
            buffers: true,
            format: .json
        )
        let jsonString = lines.joined(separator: "\n")
        let planData = try parsePostgresExplainJSON(jsonString, isAnalyze: true)

        // Also get the readable text plan
        let textLines = try await client.connection.explain(
            sql,
            analyze: true,
            verbose: true,
            buffers: true
        )
        let plan = ExecutionPlanData(
            statements: planData.statements,
            xml: textLines.joined(separator: "\n")
        )

        // Actual plan doesn't return a separate result set — return empty
        let result = QueryResultSet(columns: [], rows: [])
        return (result: result, plan: plan)
    }

    // MARK: - JSON Parsing

    private func parsePostgresExplainJSON(_ json: String, isAnalyze: Bool) throws -> ExecutionPlanData {
        guard let data = json.data(using: .utf8) else {
            throw DatabaseError.queryError("Invalid EXPLAIN output encoding")
        }

        guard let rootArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw DatabaseError.queryError("Unexpected EXPLAIN JSON structure")
        }

        var nodeCounter = 0
        var statements: [ExecutionPlanStatement] = []

        for entry in rootArray {
            guard let planDict = entry["Plan"] as? [String: Any] else { continue }

            let planningTime = entry["Planning Time"] as? Double
            let executionTime = entry["Execution Time"] as? Double
            let rootNode = parseNode(planDict, counter: &nodeCounter)

            let totalCost = rootNode.totalSubtreeCost ?? 0
            let queryPlan = ExecutionPlanQueryPlan(
                cachedPlanSize: nil,
                compileTime: planningTime.map { Int($0 * 1000) },  // ms → µs for display
                compileCPU: nil,
                rootOperator: rootNode,
                missingIndexes: []
            )

            let statementText: String
            if let planning = planningTime, let execution = executionTime {
                statementText = "Planning: \(String(format: "%.3f", planning))ms  Execution: \(String(format: "%.3f", execution))ms"
            } else {
                statementText = ""
            }

            statements.append(ExecutionPlanStatement(
                statementText: statementText,
                statementType: "SELECT",
                subtreeCost: totalCost,
                estimatedRows: rootNode.estimateRows,
                optimizationLevel: nil,
                queryPlan: queryPlan
            ))
        }

        return ExecutionPlanData(statements: statements, xml: nil)
    }

    private func parseNode(_ dict: [String: Any], counter: inout Int) -> ExecutionPlanNode {
        let nodeID = counter
        counter += 1

        let nodeType = dict["Node Type"] as? String ?? "Unknown"
        let relationName = dict["Relation Name"] as? String
        let indexName = dict["Index Name"] as? String
        let alias = dict["Alias"] as? String

        // Construct a logical operation description
        let logicalOp: String = {
            if let relation = relationName ?? indexName {
                if let a = alias, a != relation {
                    return "\(relation) (\(a))"
                }
                return relation
            }
            return nodeType
        }()

        let startupCost = dict["Startup Cost"] as? Double
        let totalCost = dict["Total Cost"] as? Double
        let planRows = dict["Plan Rows"] as? Double ?? (dict["Plan Rows"] as? Int).map(Double.init)
        let planWidth = dict["Plan Width"] as? Int

        // Actual metrics (only present with ANALYZE)
        let actualRows = dict["Actual Rows"] as? Int
        let actualLoops = dict["Actual Loops"] as? Int
        let actualTotalTime = dict["Actual Total Time"] as? Double
        let actualStartupTime = dict["Actual Startup Time"] as? Double

        // Convert actual time to ms (Postgres reports in ms already)
        let elapsedMs = actualTotalTime.map { Int($0) }
        let startupMs = actualStartupTime.map { Int($0) }
        _ = startupMs  // Available for future detail view enhancement

        // Output columns
        let output = dict["Output"] as? [String] ?? []

        // Warnings
        var warnings: [String] = []
        if let filter = dict["Filter"] as? String {
            // Not a warning per se, but useful context
            _ = filter
        }
        if let rowsRemoved = dict["Rows Removed by Filter"] as? Int, rowsRemoved > 1000 {
            warnings.append("Filter removed \(rowsRemoved) rows")
        }
        if let joinFilter = dict["Join Filter"] as? String {
            _ = joinFilter
        }
        if let rowsRemovedByJoin = dict["Rows Removed by Join Filter"] as? Int, rowsRemovedByJoin > 1000 {
            warnings.append("Join filter removed \(rowsRemovedByJoin) rows")
        }

        // Parse children
        let childDicts = dict["Plans"] as? [[String: Any]] ?? []
        var children: [ExecutionPlanNode] = []
        for childDict in childDicts {
            children.append(parseNode(childDict, counter: &counter))
        }

        // Parallel awareness
        let isParallel = dict["Parallel Aware"] as? Bool ?? false

        return ExecutionPlanNode(
            id: nodeID,
            physicalOp: nodeType,
            logicalOp: logicalOp,
            estimateRows: planRows,
            estimateIO: startupCost,
            estimateCPU: totalCost.map { total in total - (startupCost ?? 0) },
            avgRowSize: planWidth,
            totalSubtreeCost: totalCost,
            isParallel: isParallel,
            estimatedExecutions: (actualLoops ?? 1) > 1 ? Double(actualLoops!) : nil,
            actualRows: actualRows,
            actualExecutions: actualLoops,
            actualElapsedMs: elapsedMs,
            actualCPUMs: nil,
            children: children,
            outputColumns: output,
            warnings: warnings
        )
    }
}
