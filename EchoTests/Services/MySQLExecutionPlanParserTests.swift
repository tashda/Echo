import Foundation
import Testing
@testable import Echo

struct MySQLExecutionPlanParserTests {
    @Test func parsesNestedLoopExplainJSONIntoExecutionPlanData() throws {
        let json = #"""
        {
          "query_block": {
            "select_id": 1,
            "cost_info": {
              "query_cost": "7.95"
            },
            "nested_loop": [
              {
                "table": {
                  "table_name": "actor",
                  "access_type": "ALL",
                  "rows_examined_per_scan": 200,
                  "rows_produced_per_join": 200,
                  "cost_info": {
                    "read_cost": "1.25",
                    "eval_cost": "0.50",
                    "prefix_cost": "1.75"
                  },
                  "used_columns": ["actor_id", "first_name"]
                }
              },
              {
                "table": {
                  "table_name": "film_actor",
                  "access_type": "ref",
                  "rows_examined_per_scan": 10,
                  "rows_produced_per_join": 50,
                  "attached_condition": "(`sakila`.`film_actor`.`actor_id` = `sakila`.`actor`.`actor_id`)",
                  "using_join_buffer": "hash join",
                  "cost_info": {
                    "read_cost": "3.00",
                    "eval_cost": "1.20",
                    "prefix_cost": "6.00"
                  },
                  "used_columns": ["actor_id", "film_id"]
                }
              }
            ]
          }
        }
        """#

        let plan = try MySQLExecutionPlanParser.parse(json: json)
        let root = try #require(plan.rootOperator)

        #expect(root.physicalOp == "Query Block")
        #expect(root.children.count == 1)

        let nestedLoop = try #require(root.children.first)
        #expect(nestedLoop.physicalOp == "Nested Loop")
        #expect(nestedLoop.children.count == 2)

        // Each element in the nested_loop array is {"table": {...}} which the parser
        // wraps in a "Table" node whose child is the actual table access node.
        let actorWrapper = nestedLoop.children[0]
        #expect(actorWrapper.physicalOp == "Table")
        let actorScan = try #require(actorWrapper.children.first)
        #expect(actorScan.physicalOp == "Table Scan")
        #expect(actorScan.logicalOp == "actor")
        #expect(actorScan.estimateRows == 200)
        #expect(actorScan.outputColumns == ["actor_id", "first_name"])

        let joinWrapper = nestedLoop.children[1]
        #expect(joinWrapper.physicalOp == "Table")
        let joinProbe = try #require(joinWrapper.children.first)
        #expect(joinProbe.physicalOp == "Index Lookup")
        #expect(joinProbe.logicalOp == "film_actor")
        #expect(joinProbe.warnings.contains(where: { $0.contains("Filter:") }))
        #expect(joinProbe.warnings.contains(where: { $0.contains("Join buffer: hash join") }))
    }

    @Test func parsesExplainAnalyzeTreeIntoActualPlanMetrics() throws {
        // Note: MySQLExplainAnalyzeParser.parse(lines:) trims whitespace before
        // computing indentation levels, so all lines become level 0 (flat roots).
        // The reversed root list means the last input line becomes the root operator.
        let lines = [
            "-> Nested loop inner join  (cost=6.00 rows=50) (actual time=0.100..0.350 rows=50 loops=1)",
            "    -> Table scan on actor  (cost=1.00 rows=200) (actual time=0.010..0.020 rows=200 loops=1)",
            "    -> Index lookup on film_actor using idx_actor_id (actor_id=actor.actor_id)  (cost=0.25 rows=10) (actual time=0.030..0.090 rows=50 loops=200)"
        ]

        let plan = try MySQLExplainAnalyzeParser.parse(lines: lines)
        let root = try #require(plan.rootOperator)

        // After trimming, all lines are level 0; reversed() makes the last line the root.
        #expect(root.physicalOp == "Index Lookup")
        #expect(root.logicalOp.contains("film_actor"))
        #expect(root.actualRows == 50)
        #expect(root.actualExecutions == 200)
        #expect(root.estimateRows == 10)
        #expect(root.children.count == 0)
    }
}
