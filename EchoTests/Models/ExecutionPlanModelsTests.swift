import Foundation
import Testing
@testable import Echo

@Suite("ExecutionPlanData")
struct ExecutionPlanDataTests {

    // MARK: - Helpers

    private func makeNode(
        id: Int = 0,
        physicalOp: String = "Clustered Index Scan",
        logicalOp: String = "Clustered Index Scan",
        estimateRows: Double? = 100,
        estimateIO: Double? = 0.5,
        estimateCPU: Double? = 0.1,
        avgRowSize: Int? = 50,
        totalSubtreeCost: Double? = 1.0,
        isParallel: Bool = false,
        estimatedExecutions: Double? = 1.0,
        actualRows: Int? = nil,
        actualExecutions: Int? = nil,
        actualElapsedMs: Int? = nil,
        actualCPUMs: Int? = nil,
        children: [ExecutionPlanNode] = [],
        outputColumns: [String] = [],
        warnings: [String] = []
    ) -> ExecutionPlanNode {
        ExecutionPlanNode(
            id: id,
            physicalOp: physicalOp,
            logicalOp: logicalOp,
            estimateRows: estimateRows,
            estimateIO: estimateIO,
            estimateCPU: estimateCPU,
            avgRowSize: avgRowSize,
            totalSubtreeCost: totalSubtreeCost,
            isParallel: isParallel,
            estimatedExecutions: estimatedExecutions,
            actualRows: actualRows,
            actualExecutions: actualExecutions,
            actualElapsedMs: actualElapsedMs,
            actualCPUMs: actualCPUMs,
            children: children,
            outputColumns: outputColumns,
            warnings: warnings
        )
    }

    private func makePlan(
        rootOperator: ExecutionPlanNode? = nil,
        missingIndexes: [ExecutionPlanMissingIndex] = []
    ) -> ExecutionPlanData {
        let queryPlan = ExecutionPlanQueryPlan(
            cachedPlanSize: nil,
            compileTime: nil,
            compileCPU: nil,
            rootOperator: rootOperator,
            missingIndexes: missingIndexes
        )
        let statement = ExecutionPlanStatement(
            statementText: "SELECT * FROM t",
            statementType: "SELECT",
            subtreeCost: rootOperator?.totalSubtreeCost,
            estimatedRows: rootOperator?.estimateRows,
            optimizationLevel: "FULL",
            queryPlan: queryPlan
        )
        return ExecutionPlanData(statements: [statement], xml: nil)
    }

    // MARK: - rootOperator

    @Test func rootOperatorReturnsFirstStatementRoot() {
        let root = makeNode(id: 0, physicalOp: "SELECT")
        let plan = makePlan(rootOperator: root)
        #expect(plan.rootOperator?.physicalOp == "SELECT")
    }

    @Test func rootOperatorNilWhenNoStatements() {
        let plan = ExecutionPlanData(statements: [], xml: nil)
        #expect(plan.rootOperator == nil)
    }

    @Test func rootOperatorNilWhenNoQueryPlan() {
        let statement = ExecutionPlanStatement(
            statementText: "SELECT 1",
            statementType: "SELECT",
            subtreeCost: nil,
            estimatedRows: nil,
            optimizationLevel: nil,
            queryPlan: nil
        )
        let plan = ExecutionPlanData(statements: [statement], xml: nil)
        #expect(plan.rootOperator == nil)
    }

    // MARK: - missingIndexes

    @Test func missingIndexesAggregatesAcrossStatements() {
        let idx1 = ExecutionPlanMissingIndex(
            impact: 90.0, database: "mydb", schema: "dbo", table: "Users",
            equalityColumns: ["id"], inequalityColumns: [], includeColumns: []
        )
        let idx2 = ExecutionPlanMissingIndex(
            impact: 50.0, database: "mydb", schema: "dbo", table: "Orders",
            equalityColumns: ["user_id"], inequalityColumns: [], includeColumns: []
        )
        let qp1 = ExecutionPlanQueryPlan(
            cachedPlanSize: nil, compileTime: nil, compileCPU: nil,
            rootOperator: nil, missingIndexes: [idx1]
        )
        let qp2 = ExecutionPlanQueryPlan(
            cachedPlanSize: nil, compileTime: nil, compileCPU: nil,
            rootOperator: nil, missingIndexes: [idx2]
        )
        let statements = [
            ExecutionPlanStatement(
                statementText: "SELECT * FROM Users", statementType: "SELECT",
                subtreeCost: nil, estimatedRows: nil, optimizationLevel: nil, queryPlan: qp1
            ),
            ExecutionPlanStatement(
                statementText: "SELECT * FROM Orders", statementType: "SELECT",
                subtreeCost: nil, estimatedRows: nil, optimizationLevel: nil, queryPlan: qp2
            ),
        ]
        let plan = ExecutionPlanData(statements: statements, xml: nil)
        #expect(plan.missingIndexes.count == 2)
    }

    @Test func missingIndexesEmptyWhenNone() {
        let plan = makePlan(rootOperator: makeNode())
        #expect(plan.missingIndexes.isEmpty)
    }

    @Test func missingIndexesEmptyWhenNoQueryPlan() {
        let statement = ExecutionPlanStatement(
            statementText: "SELECT 1", statementType: "SELECT",
            subtreeCost: nil, estimatedRows: nil, optimizationLevel: nil, queryPlan: nil
        )
        let plan = ExecutionPlanData(statements: [statement], xml: nil)
        #expect(plan.missingIndexes.isEmpty)
    }
}

@Suite("ExecutionPlanNode")
struct ExecutionPlanNodeTests {

    private func makeNode(
        totalSubtreeCost: Double? = nil,
        children: [ExecutionPlanNode] = []
    ) -> ExecutionPlanNode {
        ExecutionPlanNode(
            id: 0, physicalOp: "Op", logicalOp: "Op",
            estimateRows: nil, estimateIO: nil, estimateCPU: nil,
            avgRowSize: nil, totalSubtreeCost: totalSubtreeCost,
            isParallel: false, estimatedExecutions: nil,
            actualRows: nil, actualExecutions: nil,
            actualElapsedMs: nil, actualCPUMs: nil,
            children: children, outputColumns: [], warnings: []
        )
    }

    // MARK: - operatorCost

    @Test func operatorCostWithNoChildrenEqualsSubtreeCost() {
        let node = makeNode(totalSubtreeCost: 5.0)
        #expect(node.operatorCost == 5.0)
    }

    @Test func operatorCostSubtractsChildCosts() {
        let child1 = makeNode(totalSubtreeCost: 2.0)
        let child2 = makeNode(totalSubtreeCost: 1.5)
        let parent = makeNode(totalSubtreeCost: 5.0, children: [child1, child2])
        #expect(parent.operatorCost == 1.5)
    }

    @Test func operatorCostNeverNegative() {
        // Child costs exceed parent subtree cost
        let child = makeNode(totalSubtreeCost: 10.0)
        let parent = makeNode(totalSubtreeCost: 5.0, children: [child])
        #expect(parent.operatorCost == 0.0)
    }

    @Test func operatorCostNilWhenSubtreeCostNil() {
        let node = makeNode(totalSubtreeCost: nil)
        #expect(node.operatorCost == nil)
    }

    @Test func operatorCostZeroSubtreeCost() {
        let node = makeNode(totalSubtreeCost: 0.0)
        #expect(node.operatorCost == 0.0)
    }

    @Test func operatorCostIgnoresChildrenWithNilCost() {
        let child1 = makeNode(totalSubtreeCost: nil)
        let child2 = makeNode(totalSubtreeCost: 2.0)
        let parent = makeNode(totalSubtreeCost: 5.0, children: [child1, child2])
        // Only child2's cost is subtracted: 5.0 - 2.0 = 3.0
        #expect(parent.operatorCost == 3.0)
    }

    // MARK: - costPercentage

    @Test func costPercentageEqualsOperatorCost() {
        let node = makeNode(totalSubtreeCost: 5.0)
        #expect(node.costPercentage == node.operatorCost)
    }

    @Test func costPercentageNilWhenOperatorCostNil() {
        let node = makeNode(totalSubtreeCost: nil)
        #expect(node.costPercentage == nil)
    }

    // MARK: - Nested Hierarchies

    @Test func threeLayerHierarchy() {
        let leaf = makeNode(totalSubtreeCost: 1.0)
        let middle = makeNode(totalSubtreeCost: 3.0, children: [leaf])
        let root = makeNode(totalSubtreeCost: 5.0, children: [middle])

        #expect(leaf.operatorCost == 1.0)
        #expect(middle.operatorCost == 2.0)   // 3.0 - 1.0
        #expect(root.operatorCost == 2.0)     // 5.0 - 3.0
    }

    @Test func multipleChildrenAtSameLevel() {
        let child1 = makeNode(totalSubtreeCost: 1.0)
        let child2 = makeNode(totalSubtreeCost: 1.5)
        let child3 = makeNode(totalSubtreeCost: 0.5)
        let root = makeNode(totalSubtreeCost: 5.0, children: [child1, child2, child3])
        // 5.0 - (1.0 + 1.5 + 0.5) = 2.0
        #expect(root.operatorCost == 2.0)
    }
}

@Suite("ExecutionPlanMissingIndex")
struct ExecutionPlanMissingIndexTests {

    @Test func createStatementWithSchemaAndTable() {
        let idx = ExecutionPlanMissingIndex(
            impact: 95.0,
            database: "mydb",
            schema: "dbo",
            table: "Users",
            equalityColumns: ["id", "name"],
            inequalityColumns: [],
            includeColumns: []
        )
        let stmt = idx.createStatement
        #expect(stmt.contains("CREATE INDEX"))
        #expect(stmt.contains("[dbo].[Users]"))
        #expect(stmt.contains("[id], [name]"))
        #expect(stmt.contains("IX_Users_"))
    }

    @Test func createStatementWithTableOnly() {
        let idx = ExecutionPlanMissingIndex(
            impact: 80.0,
            database: nil,
            schema: nil,
            table: "Orders",
            equalityColumns: ["order_id"],
            inequalityColumns: [],
            includeColumns: []
        )
        let stmt = idx.createStatement
        #expect(stmt.contains("[Orders]"))
        #expect(!stmt.contains("[nil]"))
    }

    @Test func createStatementWithIncludeColumns() {
        let idx = ExecutionPlanMissingIndex(
            impact: 70.0,
            database: "mydb",
            schema: "dbo",
            table: "Products",
            equalityColumns: ["category_id"],
            inequalityColumns: [],
            includeColumns: ["name", "price"]
        )
        let stmt = idx.createStatement
        #expect(stmt.contains("INCLUDE"))
        #expect(stmt.contains("[name], [price]"))
    }

    @Test func createStatementWithoutIncludeColumns() {
        let idx = ExecutionPlanMissingIndex(
            impact: 60.0,
            database: "mydb",
            schema: "dbo",
            table: "Items",
            equalityColumns: ["id"],
            inequalityColumns: [],
            includeColumns: []
        )
        let stmt = idx.createStatement
        #expect(!stmt.contains("INCLUDE"))
    }

    @Test func createStatementCombinesEqualityAndInequalityColumns() {
        let idx = ExecutionPlanMissingIndex(
            impact: 85.0,
            database: "mydb",
            schema: "dbo",
            table: "Sales",
            equalityColumns: ["region"],
            inequalityColumns: ["sale_date"],
            includeColumns: ["amount"]
        )
        let stmt = idx.createStatement
        #expect(stmt.contains("[region], [sale_date]"))
        #expect(stmt.contains("INCLUDE ([amount])"))
    }

    @Test func createStatementWithNilTable() {
        let idx = ExecutionPlanMissingIndex(
            impact: 50.0,
            database: nil,
            schema: nil,
            table: nil,
            equalityColumns: ["col"],
            inequalityColumns: [],
            includeColumns: []
        )
        let stmt = idx.createStatement
        #expect(stmt.contains("IX_unknown_"))
    }

    @Test func createStatementIndexNameContainsColumnNames() {
        let idx = ExecutionPlanMissingIndex(
            impact: 90.0,
            database: "db",
            schema: "dbo",
            table: "T",
            equalityColumns: ["a"],
            inequalityColumns: ["b"],
            includeColumns: []
        )
        let stmt = idx.createStatement
        #expect(stmt.contains("IX_T_a_b"))
    }

    @Test func missingIndexHasUniqueID() {
        let idx1 = ExecutionPlanMissingIndex(
            impact: nil, database: nil, schema: nil, table: nil,
            equalityColumns: [], inequalityColumns: [], includeColumns: []
        )
        let idx2 = ExecutionPlanMissingIndex(
            impact: nil, database: nil, schema: nil, table: nil,
            equalityColumns: [], inequalityColumns: [], includeColumns: []
        )
        #expect(idx1.id != idx2.id)
    }
}

@Suite("ExecutionPlanStatement")
struct ExecutionPlanStatementTests {

    @Test func statementFieldsAreAccessible() {
        let statement = ExecutionPlanStatement(
            statementText: "SELECT 1",
            statementType: "SELECT",
            subtreeCost: 0.001,
            estimatedRows: 1.0,
            optimizationLevel: "TRIVIAL",
            queryPlan: nil
        )
        #expect(statement.statementText == "SELECT 1")
        #expect(statement.statementType == "SELECT")
        #expect(statement.subtreeCost == 0.001)
        #expect(statement.estimatedRows == 1.0)
        #expect(statement.optimizationLevel == "TRIVIAL")
        #expect(statement.queryPlan == nil)
    }
}

@Suite("ExecutionPlanQueryPlan")
struct ExecutionPlanQueryPlanTests {

    @Test func queryPlanFieldsAreAccessible() {
        let qp = ExecutionPlanQueryPlan(
            cachedPlanSize: 1024,
            compileTime: 50,
            compileCPU: 30,
            rootOperator: nil,
            missingIndexes: []
        )
        #expect(qp.cachedPlanSize == 1024)
        #expect(qp.compileTime == 50)
        #expect(qp.compileCPU == 30)
        #expect(qp.rootOperator == nil)
        #expect(qp.missingIndexes.isEmpty)
    }
}
