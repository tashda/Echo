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

        let actorScan = nestedLoop.children[0]
        #expect(actorScan.physicalOp == "Table Scan")
        #expect(actorScan.logicalOp == "actor")
        #expect(actorScan.estimateRows == 200)
        #expect(actorScan.outputColumns == ["actor_id", "first_name"])

        let joinProbe = nestedLoop.children[1]
        #expect(joinProbe.physicalOp == "Index Lookup")
        #expect(joinProbe.logicalOp == "film_actor")
        #expect(joinProbe.warnings.contains(where: { $0.contains("Filter:") }))
        #expect(joinProbe.warnings.contains(where: { $0.contains("Join buffer: hash join") }))
    }
}
