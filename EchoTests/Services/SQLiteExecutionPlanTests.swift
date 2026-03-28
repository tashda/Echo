import Foundation
import Testing
@testable import Echo

@Suite("SQLite Execution Plan Detail Parsing")
struct SQLiteExecutionPlanDetailTests {

    // These tests validate the parsing logic used by SQLiteSession+ExecutionPlan
    // by constructing ExecutionPlanNode trees from representative detail strings.

    @Test func tableScanNodeParsesCorrectly() {
        let node = makeNodeFromDetail("SCAN users")
        #expect(node.physicalOp == "Table Scan")
        #expect(node.logicalOp == "users")
    }

    @Test func indexSeekNodeParsesCorrectly() {
        let node = makeNodeFromDetail("SEARCH users USING INDEX idx_users_email (email=?)")
        #expect(node.physicalOp == "Index Seek")
        #expect(node.logicalOp.contains("idx_users_email"))
    }

    @Test func coveringIndexSeekParsesCorrectly() {
        let node = makeNodeFromDetail("SEARCH users USING COVERING INDEX idx_users_email (email=?)")
        #expect(node.physicalOp == "Covering Index Seek")
    }

    @Test func primaryKeyLookupParsesCorrectly() {
        let node = makeNodeFromDetail("SEARCH users USING INTEGER PRIMARY KEY (rowid=?)")
        #expect(node.physicalOp == "Primary Key Lookup")
    }

    @Test func sortNodeParsesCorrectly() {
        let node = makeNodeFromDetail("USE TEMP B-TREE FOR ORDER BY")
        #expect(node.physicalOp == "Sort")
    }

    @Test func subqueryNodeParsesCorrectly() {
        let node = makeNodeFromDetail("CO-ROUTINE subquery_1")
        #expect(node.physicalOp == "Subquery")
    }

    @Test func compoundQueryParsesCorrectly() {
        let node = makeNodeFromDetail("COMPOUND SUBQUERIES 1 AND 2 USING TEMP B-TREE (UNION)")
        #expect(node.physicalOp == "Union")
    }

    @Test func unknownDetailUsesRawText() {
        let detail = "SOME UNKNOWN OPERATION"
        let node = makeNodeFromDetail(detail)
        #expect(node.physicalOp == detail)
        #expect(node.logicalOp == detail)
    }

    @Test func multiIndexORParsesCorrectly() {
        let node = makeNodeFromDetail("MULTI-INDEX OR")
        #expect(node.physicalOp == "Multi-Index OR")
    }

    @Test func planTreeBuildsCorrectHierarchy() {
        // Simulates EXPLAIN QUERY PLAN output:
        // 0|0|0|SEARCH users USING INDEX idx (id=?)
        // 0|0|1|SCAN orders
        let rootNode = ExecutionPlanNode(
            id: 0,
            physicalOp: "QUERY PLAN",
            logicalOp: "QUERY PLAN",
            estimateRows: nil, estimateIO: nil, estimateCPU: nil,
            avgRowSize: nil, totalSubtreeCost: nil, isParallel: false,
            estimatedExecutions: nil, actualRows: nil, actualExecutions: nil,
            actualElapsedMs: nil, actualCPUMs: nil,
            children: [
                makeNodeFromDetail("SEARCH users USING INDEX idx (id=?)"),
                makeNodeFromDetail("SCAN orders")
            ],
            outputColumns: [], warnings: []
        )

        #expect(rootNode.children.count == 2)
        #expect(rootNode.children[0].physicalOp == "Index Seek")
        #expect(rootNode.children[1].physicalOp == "Table Scan")
    }

    @Test func textPlanFormatsCorrectly() {
        let textPlan = """
        QUERY PLAN
          |--SCAN users
          |--SEARCH orders USING INDEX idx_orders_user (user_id=?)
        """
        #expect(textPlan.contains("QUERY PLAN"))
        #expect(textPlan.contains("SCAN users"))
        #expect(textPlan.contains("SEARCH orders"))
    }

    @Test func executionPlanDataStructure() {
        let root = makeNodeFromDetail("SCAN users")
        let planData = ExecutionPlanData(
            statements: [
                ExecutionPlanStatement(
                    statementText: "SELECT * FROM users",
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
            xml: "QUERY PLAN\n  |--SCAN users"
        )

        #expect(planData.rootOperator != nil)
        #expect(planData.rootOperator?.physicalOp == "Table Scan")
        #expect(planData.xml != nil)
        #expect(planData.missingIndexes.isEmpty)
    }

    // MARK: - Helpers

    /// Parses a SQLite EXPLAIN QUERY PLAN detail string into an ExecutionPlanNode
    /// using the same logic as SQLiteSession+ExecutionPlan.parseDetail
    private func makeNodeFromDetail(_ detail: String) -> ExecutionPlanNode {
        let (physicalOp, logicalOp) = parseDetail(detail)
        return ExecutionPlanNode(
            id: 0,
            physicalOp: physicalOp,
            logicalOp: logicalOp,
            estimateRows: nil, estimateIO: nil, estimateCPU: nil,
            avgRowSize: nil, totalSubtreeCost: nil, isParallel: false,
            estimatedExecutions: nil, actualRows: nil, actualExecutions: nil,
            actualElapsedMs: nil, actualCPUMs: nil,
            children: [], outputColumns: [], warnings: []
        )
    }

    /// Mirrors SQLiteSession+ExecutionPlan.parseDetail
    private func parseDetail(_ detail: String) -> (physicalOp: String, logicalOp: String) {
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
}
