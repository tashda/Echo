import Foundation
import SQLServerKit

extension SQLServerSessionAdapter: ExecutionPlanProviding {
    func getEstimatedExecutionPlan(_ sql: String) async throws -> ExecutionPlanData {
        let plan = try await client.executionPlan.estimated(sql)
        return convertShowPlan(plan)
    }

    func getActualExecutionPlan(_ sql: String) async throws -> (result: QueryResultSet, plan: ExecutionPlanData) {
        let (executionResult, plan) = try await client.executionPlan.actual(sql)
        let columns = executionResult.rows.first.map { row in
            row.values.enumerated().map { index, _ in
                ColumnInfo(name: "Column\(index)", dataType: "nvarchar")
            }
        } ?? []
        let rows = executionResult.rows.map { row in
            row.values.map { $0.string }
        }
        let resultSet = QueryResultSet(columns: columns, rows: rows)
        return (result: resultSet, plan: convertShowPlan(plan))
    }

    private func convertShowPlan(_ plan: ShowPlan) -> ExecutionPlanData {
        ExecutionPlanData(
            statements: plan.statements.map { convertStatement($0) },
            xml: plan.xml
        )
    }

    private func convertStatement(_ stmt: ShowPlanStatement) -> ExecutionPlanStatement {
        ExecutionPlanStatement(
            statementText: stmt.statementText,
            statementType: stmt.statementType,
            subtreeCost: stmt.statementSubTreeCost,
            estimatedRows: stmt.statementEstRows,
            optimizationLevel: stmt.optimizationLevel,
            queryPlan: stmt.queryPlan.map { convertQueryPlan($0) }
        )
    }

    private func convertQueryPlan(_ qp: ShowPlanQueryPlan) -> ExecutionPlanQueryPlan {
        ExecutionPlanQueryPlan(
            cachedPlanSize: qp.cachedPlanSize,
            compileTime: qp.compileTime,
            compileCPU: qp.compileCPU,
            rootOperator: qp.rootOperator.map { convertOperator($0) },
            missingIndexes: qp.missingIndexes.map { convertMissingIndex($0) }
        )
    }

    private func convertOperator(_ op: ShowPlanOperator) -> ExecutionPlanNode {
        ExecutionPlanNode(
            id: op.nodeId,
            physicalOp: op.physicalOp,
            logicalOp: op.logicalOp,
            estimateRows: op.estimateRows,
            estimateIO: op.estimateIO,
            estimateCPU: op.estimateCPU,
            avgRowSize: op.avgRowSize,
            totalSubtreeCost: op.totalSubtreeCost,
            isParallel: op.isParallel,
            estimatedExecutions: op.estimatedExecutions,
            actualRows: op.actualRows,
            actualExecutions: op.actualExecutions,
            actualElapsedMs: op.actualElapsedMs,
            actualCPUMs: op.actualCPUMs,
            children: op.children.map { convertOperator($0) },
            outputColumns: op.outputColumns.map { col in
                [col.table, col.column].compactMap { $0 }.joined(separator: ".")
            },
            warnings: op.warnings
        )
    }

    private func convertMissingIndex(_ idx: ShowPlanMissingIndex) -> ExecutionPlanMissingIndex {
        ExecutionPlanMissingIndex(
            impact: idx.impact,
            database: idx.database,
            schema: idx.schema,
            table: idx.table,
            equalityColumns: idx.equalityColumns,
            inequalityColumns: idx.inequalityColumns,
            includeColumns: idx.includeColumns
        )
    }
}
