import Foundation

extension MSSQLDedicatedQuerySession: ExecutionPlanProviding {
    func getEstimatedExecutionPlan(_ sql: String) async throws -> ExecutionPlanData {
        guard let provider = metadataSession as? ExecutionPlanProviding else {
            throw DatabaseError.queryError("Execution plans are not supported for this session")
        }
        return try await provider.getEstimatedExecutionPlan(sql)
    }

    func getActualExecutionPlan(_ sql: String) async throws -> (result: QueryResultSet, plan: ExecutionPlanData) {
        guard let provider = metadataSession as? ExecutionPlanProviding else {
            throw DatabaseError.queryError("Execution plans are not supported for this session")
        }
        return try await provider.getActualExecutionPlan(sql)
    }
}
