import Foundation

extension MSSQLDedicatedQuerySession: ExecutionPlanProviding {
    func getEstimatedExecutionPlan(_ sql: String) async throws -> ExecutionPlanData {
        try await metadataSession.getEstimatedExecutionPlan(sql)
    }

    func getActualExecutionPlan(_ sql: String) async throws -> (result: QueryResultSet, plan: ExecutionPlanData) {
        try await metadataSession.getActualExecutionPlan(sql)
    }
}
