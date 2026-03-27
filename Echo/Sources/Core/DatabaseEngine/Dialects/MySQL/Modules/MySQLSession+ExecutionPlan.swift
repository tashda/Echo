import Foundation
import MySQLKit

extension MySQLSession: ExecutionPlanProviding {
    func getEstimatedExecutionPlan(_ sql: String) async throws -> ExecutionPlanData {
        let plan = try await client.performance.explainJSON(sql)
        return try MySQLExecutionPlanParser.parse(json: plan.json)
    }

    func getActualExecutionPlan(_ sql: String) async throws -> (result: QueryResultSet, plan: ExecutionPlanData) {
        let estimatedPlan = try await getEstimatedExecutionPlan(sql)
        let analyzeOutput = try? await client.performance.explainAnalyze(sql)
        let plan = ExecutionPlanData(
            statements: estimatedPlan.statements,
            xml: analyzeOutput?.lines.joined(separator: "\n") ?? estimatedPlan.xml
        )
        return (result: QueryResultSet(columns: [], rows: []), plan: plan)
    }
}
