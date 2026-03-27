import Foundation

enum MySQLExecutionPlanParser {
    static func parse(json: String) throws -> ExecutionPlanData {
        guard let data = json.data(using: .utf8) else {
            throw DatabaseError.queryError("Invalid MySQL EXPLAIN JSON encoding")
        }

        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DatabaseError.queryError("Unexpected MySQL EXPLAIN JSON structure")
        }

        var counter = 0
        guard let rootNode = parseNode(value: root, keyHint: nil, counter: &counter) else {
            throw DatabaseError.queryError("MySQL EXPLAIN JSON did not contain a query plan")
        }

        let statement = ExecutionPlanStatement(
            statementText: "MySQL EXPLAIN FORMAT=JSON",
            statementType: rootNode.physicalOp,
            subtreeCost: rootNode.totalSubtreeCost,
            estimatedRows: rootNode.estimateRows,
            optimizationLevel: nil,
            queryPlan: ExecutionPlanQueryPlan(
                cachedPlanSize: nil,
                compileTime: nil,
                compileCPU: nil,
                rootOperator: rootNode,
                missingIndexes: []
            )
        )

        return ExecutionPlanData(statements: [statement], xml: json)
    }

    private static func parseNode(value: Any, keyHint: String?, counter: inout Int) -> ExecutionPlanNode? {
        if let dict = value as? [String: Any] {
            return parseDictionary(dict, keyHint: keyHint, counter: &counter)
        }

        if let array = value as? [Any] {
            return parseArray(array, keyHint: keyHint, counter: &counter)
        }

        return nil
    }

    private static func parseDictionary(_ dict: [String: Any], keyHint: String?, counter: inout Int) -> ExecutionPlanNode? {
        if let queryBlock = dict["query_block"] {
            return parseNode(value: queryBlock, keyHint: "query_block", counter: &counter)
        }

        if let tableName = stringValue(dict["table_name"]) {
            return parseTableNode(dict, tableName: tableName, counter: &counter)
        }

        let resolvedKey = keyHint ?? firstOperationKey(in: dict)
        let children = childNodes(in: dict, keyHint: resolvedKey, counter: &counter)
        guard !children.isEmpty || resolvedKey != nil else { return nil }

        let costInfo = (dict["cost_info"] as? [String: Any]) ?? [:]
        let estimateRows = numericValue(dict["rows_produced_per_join"])
            ?? numericValue(dict["rows_examined_per_scan"])
            ?? children.compactMap(\.estimateRows).max()
        let totalCost = numericValue(costInfo["query_cost"])
            ?? numericValue(costInfo["prefix_cost"])
            ?? children.compactMap(\.totalSubtreeCost).reduce(0, +)
        let readCost = numericValue(costInfo["read_cost"])
        let evalCost = numericValue(costInfo["eval_cost"])
        let warnings = warningStrings(from: dict)

        let nodeID = counter
        counter += 1

        let physicalOp = displayName(for: resolvedKey ?? "operation")
        let logicalOp: String = {
            if let selectID = stringValue(dict["select_id"]) {
                return "Select \(selectID)"
            }
            return physicalOp
        }()

        return ExecutionPlanNode(
            id: nodeID,
            physicalOp: physicalOp,
            logicalOp: logicalOp,
            estimateRows: estimateRows,
            estimateIO: readCost,
            estimateCPU: evalCost,
            avgRowSize: intValue(dict["data_read_per_join"]),
            totalSubtreeCost: totalCost,
            isParallel: false,
            estimatedExecutions: nil,
            actualRows: nil,
            actualExecutions: nil,
            actualElapsedMs: nil,
            actualCPUMs: nil,
            children: children,
            outputColumns: stringArray(dict["used_columns"]),
            warnings: warnings
        )
    }

    private static func parseArray(_ array: [Any], keyHint: String?, counter: inout Int) -> ExecutionPlanNode? {
        let children = array.compactMap { parseNode(value: $0, keyHint: nil, counter: &counter) }
        guard !children.isEmpty else { return nil }

        let nodeID = counter
        counter += 1

        return ExecutionPlanNode(
            id: nodeID,
            physicalOp: displayName(for: keyHint ?? "operation"),
            logicalOp: displayName(for: keyHint ?? "operation"),
            estimateRows: children.compactMap(\.estimateRows).max(),
            estimateIO: nil,
            estimateCPU: nil,
            avgRowSize: nil,
            totalSubtreeCost: children.compactMap(\.totalSubtreeCost).reduce(0, +),
            isParallel: false,
            estimatedExecutions: nil,
            actualRows: nil,
            actualExecutions: nil,
            actualElapsedMs: nil,
            actualCPUMs: nil,
            children: children,
            outputColumns: [],
            warnings: []
        )
    }

    private static func parseTableNode(_ dict: [String: Any], tableName: String, counter: inout Int) -> ExecutionPlanNode {
        let costInfo = (dict["cost_info"] as? [String: Any]) ?? [:]
        let nodeID = counter
        counter += 1

        return ExecutionPlanNode(
            id: nodeID,
            physicalOp: accessTypeName(stringValue(dict["access_type"])),
            logicalOp: tableName,
            estimateRows: numericValue(dict["rows_produced_per_join"])
                ?? numericValue(dict["rows_examined_per_scan"]),
            estimateIO: numericValue(costInfo["read_cost"]),
            estimateCPU: numericValue(costInfo["eval_cost"]),
            avgRowSize: intValue(dict["data_read_per_join"]),
            totalSubtreeCost: numericValue(costInfo["prefix_cost"])
                ?? numericValue(costInfo["query_cost"]),
            isParallel: false,
            estimatedExecutions: nil,
            actualRows: nil,
            actualExecutions: nil,
            actualElapsedMs: nil,
            actualCPUMs: nil,
            children: childNodes(in: dict, keyHint: "table", counter: &counter),
            outputColumns: stringArray(dict["used_columns"]),
            warnings: warningStrings(from: dict)
        )
    }

    private static func childNodes(in dict: [String: Any], keyHint: String?, counter: inout Int) -> [ExecutionPlanNode] {
        var children: [ExecutionPlanNode] = []

        for key in orderedChildKeys(in: dict, preferredKey: keyHint) {
            guard let value = dict[key] else { continue }

            if key == "table", let nested = value as? [String: Any], let tableName = stringValue(nested["table_name"]) {
                children.append(parseTableNode(nested, tableName: tableName, counter: &counter))
                continue
            }

            if let child = parseNode(value: value, keyHint: key, counter: &counter) {
                children.append(child)
            }
        }

        return children
    }

    private static func orderedChildKeys(in dict: [String: Any], preferredKey: String?) -> [String] {
        let preferredOrder = [
            "nested_loop",
            "table",
            "grouping_operation",
            "ordering_operation",
            "duplicates_removal",
            "buffer_result",
            "windowing",
            "query_specifications",
            "query_block",
            "materialized_from_subquery",
            "optimized_away_subqueries",
            "attached_subqueries",
            "select_list_subqueries",
            "having_subqueries",
            "union_result"
        ]

        let remainingKeys = Set(dict.keys).subtracting(nonChildKeys)
        let ordered = preferredOrder.filter { remainingKeys.contains($0) }
        let unordered = remainingKeys.subtracting(ordered).sorted()

        if let preferredKey, ordered.contains(preferredKey) {
            return ordered + unordered
        }

        return ordered + unordered
    }

    private static func firstOperationKey(in dict: [String: Any]) -> String? {
        orderedOperationKeys.first { dict[$0] != nil }
    }

    private static func warningStrings(from dict: [String: Any]) -> [String] {
        var warnings: [String] = []

        if let condition = stringValue(dict["attached_condition"]) {
            warnings.append("Filter: \(condition)")
        }
        if let joinBuffer = stringValue(dict["using_join_buffer"]) {
            warnings.append("Join buffer: \(joinBuffer)")
        }
        if (dict["using_filesort"] as? Bool) == true {
            warnings.append("Uses filesort")
        }
        if (dict["using_temporary_table"] as? Bool) == true {
            warnings.append("Uses temporary table")
        }

        return warnings
    }

    private static func accessTypeName(_ accessType: String?) -> String {
        switch accessType?.lowercased() {
        case "all":
            return "Table Scan"
        case "index":
            return "Index Scan"
        case "range":
            return "Range Scan"
        case "ref":
            return "Index Lookup"
        case "eq_ref":
            return "Unique Lookup"
        case "const":
            return "Const Lookup"
        case "system":
            return "System Table"
        case "index_merge":
            return "Index Merge"
        case let value?:
            return displayName(for: value)
        case nil:
            return "Table Access"
        }
    }

    private static func displayName(for key: String) -> String {
        key
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private static func stringArray(_ value: Any?) -> [String] {
        (value as? [String]) ?? []
    }

    private static func stringValue(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            return string
        case let int as Int:
            return String(int)
        case let double as Double:
            return String(double)
        default:
            return nil
        }
    }

    private static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let int as Int:
            return int
        case let string as String:
            return Int(string)
        case let double as Double:
            return Int(double)
        default:
            return nil
        }
    }

    private static func numericValue(_ value: Any?) -> Double? {
        switch value {
        case let double as Double:
            return double
        case let int as Int:
            return Double(int)
        case let string as String:
            return Double(string)
        default:
            return nil
        }
    }

    private static let orderedOperationKeys = [
        "query_block",
        "nested_loop",
        "table",
        "grouping_operation",
        "ordering_operation",
        "duplicates_removal",
        "buffer_result",
        "windowing",
        "query_specifications",
        "union_result",
        "materialized_from_subquery",
        "optimized_away_subqueries",
        "attached_subqueries",
        "select_list_subqueries",
        "having_subqueries"
    ]

    private static let nonChildKeys: Set<String> = [
        "select_id",
        "message",
        "cost_info",
        "table_name",
        "access_type",
        "possible_keys",
        "key",
        "key_length",
        "used_key_parts",
        "ref",
        "rows_examined_per_scan",
        "rows_produced_per_join",
        "filtered",
        "used_columns",
        "attached_condition",
        "using_join_buffer",
        "using_filesort",
        "using_temporary_table",
        "data_read_per_join"
    ]
}
