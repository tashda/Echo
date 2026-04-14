import Foundation
import MySQLKit

extension MySQLSession: ExecutionPlanProviding {
    func getEstimatedExecutionPlan(_ sql: String) async throws -> ExecutionPlanData {
        let plan = try await client.executionPlan.explainJSON(sql)
        return try MySQLExecutionPlanParser.parse(json: plan.json)
    }

    func getActualExecutionPlan(_ sql: String) async throws -> (result: QueryResultSet, plan: ExecutionPlanData) {
        let analyzeOutput = try await client.executionPlan.explainAnalyze(sql)
        let plan = try MySQLExplainAnalyzeParser.parse(lines: analyzeOutput.lines)
        return (result: QueryResultSet(columns: [], rows: []), plan: plan)
    }
}
