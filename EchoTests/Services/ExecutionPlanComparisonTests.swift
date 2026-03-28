import Foundation
import Testing
import SQLServerKit
@testable import Echo

@Suite("ShowPlan XML Comparison Parsing")
struct ExecutionPlanComparisonTests {

    @Test func parsesShowPlanXMLIntoExecutionPlanData() throws {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <ShowPlanXML xmlns="http://schemas.microsoft.com/sqlserver/2004/07/showplan" Version="1.2" Build="16.0.1000.6">
          <BatchSequence>
            <Batch>
              <Statements>
                <StmtSimple StatementText="SELECT * FROM Users" StatementType="SELECT" StatementSubTreeCost="0.0032831">
                  <QueryPlan CachedPlanSize="16" CompileTime="1" CompileCPU="1">
                    <RelOp NodeId="0" PhysicalOp="Clustered Index Scan" LogicalOp="Clustered Index Scan" EstimateRows="100" EstimateCPU="0.000286" EstimateIO="0.003125" AvgRowSize="50" EstimatedTotalSubtreeCost="0.0032831" Parallel="0">
                      <OutputList>
                        <ColumnReference Database="mydb" Schema="dbo" Table="Users" Column="id"/>
                        <ColumnReference Database="mydb" Schema="dbo" Table="Users" Column="name"/>
                      </OutputList>
                    </RelOp>
                  </QueryPlan>
                </StmtSimple>
              </Statements>
            </Batch>
          </BatchSequence>
        </ShowPlanXML>
        """

        let showPlan = try ShowPlanXMLParser.parse(xml: xml)
        #expect(showPlan.statements.count == 1)

        let stmt = showPlan.statements[0]
        #expect(stmt.statementType == "SELECT")
        #expect(stmt.statementSubTreeCost != nil)

        let root = stmt.queryPlan?.rootOperator
        #expect(root != nil)
        #expect(root?.physicalOp == "Clustered Index Scan")
        #expect(root?.estimateRows == 100)
        #expect(root?.outputColumns.count == 2)
    }

    @Test func convertShowPlanOperatorToExecutionPlanNode() throws {
        let op = ShowPlanOperator(
            nodeId: 1,
            physicalOp: "Hash Match",
            logicalOp: "Inner Join",
            estimateRows: 500,
            estimateIO: 0.1,
            estimateCPU: 0.05,
            avgRowSize: 100,
            totalSubtreeCost: 0.5,
            isParallel: true,
            estimatedExecutions: 2.0,
            actualRows: 480,
            actualExecutions: 2,
            actualElapsedMs: 15,
            actualCPUMs: 10,
            children: [],
            outputColumns: [
                ShowPlanColumnReference(database: "db", schema: "dbo", table: "T", column: "id")
            ],
            warnings: ["SpillToTempDb"]
        )

        let node = convertOperator(op)
        #expect(node.id == 1)
        #expect(node.physicalOp == "Hash Match")
        #expect(node.logicalOp == "Inner Join")
        #expect(node.isParallel == true)
        #expect(node.actualRows == 480)
        #expect(node.outputColumns.count == 1)
        #expect(node.outputColumns[0] == "T.id")
        #expect(node.warnings == ["SpillToTempDb"])
    }

    @Test func convertNestedOperatorTree() {
        let child = ShowPlanOperator(
            nodeId: 2, physicalOp: "Index Seek", logicalOp: "Index Seek",
            estimateRows: 10, estimateIO: nil, estimateCPU: nil,
            avgRowSize: nil, totalSubtreeCost: 0.001, isParallel: false,
            estimatedExecutions: nil, actualRows: nil, actualExecutions: nil,
            actualElapsedMs: nil, actualCPUMs: nil, children: [],
            outputColumns: [], warnings: []
        )
        let parent = ShowPlanOperator(
            nodeId: 1, physicalOp: "Nested Loops", logicalOp: "Inner Join",
            estimateRows: 100, estimateIO: nil, estimateCPU: nil,
            avgRowSize: nil, totalSubtreeCost: 0.01, isParallel: false,
            estimatedExecutions: nil, actualRows: nil, actualExecutions: nil,
            actualElapsedMs: nil, actualCPUMs: nil, children: [child],
            outputColumns: [], warnings: []
        )

        let node = convertOperator(parent)
        #expect(node.children.count == 1)
        #expect(node.children[0].physicalOp == "Index Seek")
        #expect(node.operatorCost == 0.01 - 0.001)
    }

    // MARK: - Helpers

    /// Converts ShowPlanOperator to ExecutionPlanNode — mirrors the logic in
    /// ExecutionPlanComparisonView.convertOperator
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
}
