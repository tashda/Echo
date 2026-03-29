import Foundation

enum MySQLExplainAnalyzeParser {
    static func parse(lines: [String]) throws -> ExecutionPlanData {
        let planLines = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !planLines.isEmpty else {
            throw DatabaseError.queryError("MySQL EXPLAIN ANALYZE did not return a plan")
        }

        let parsedNodes = try planLines.enumerated().map { index, line in
            try ParsedLine(index: index, rawLine: line)
        }

        let rootNodes = buildTree(from: parsedNodes)
        guard let rootNode = rootNodes.first else {
            throw DatabaseError.queryError("MySQL EXPLAIN ANALYZE did not contain any plan nodes")
        }

        let statement = ExecutionPlanStatement(
            statementText: "MySQL EXPLAIN ANALYZE",
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

        return ExecutionPlanData(
            statements: [statement],
            xml: planLines.joined(separator: "\n")
        )
    }

    private static func buildTree(from parsedLines: [ParsedLine]) -> [ExecutionPlanNode] {
        struct Frame {
            let level: Int
            var node: MutableNode
        }

        var roots: [MutableNode] = []
        var stack: [Frame] = []

        for parsed in parsedLines {
            let mutable = MutableNode(parsed)

            while let last = stack.last, last.level >= parsed.level {
                let completed = stack.removeLast()
                if stack.isEmpty {
                    roots.append(completed.node)
                } else {
                    stack[stack.count - 1].node.children.append(completed.node)
                }
            }

            stack.append(Frame(level: parsed.level, node: mutable))
        }

        while let completed = stack.popLast() {
            if stack.isEmpty {
                roots.append(completed.node)
            } else {
                stack[stack.count - 1].node.children.append(completed.node)
            }
        }

        return roots.reversed().map { $0.makeExecutionPlanNode() }
    }
}

private struct ParsedLine {
    let index: Int
    let level: Int
    let description: String
    let physicalOp: String
    let logicalOp: String
    let estimateRows: Double?
    let totalSubtreeCost: Double?
    let actualRows: Int?
    let actualExecutions: Int?
    let actualElapsedMs: Int?

    init(index: Int, rawLine: String) throws {
        self.index = index

        let leadingSpaces = rawLine.prefix { $0 == " " }.count
        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
        let arrowStripped = trimmed.hasPrefix("->") ? String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces) : trimmed
        self.level = max(leadingSpaces / 4, 0)

        let descriptionEnd = arrowStripped.range(of: "  (")?.lowerBound ?? arrowStripped.endIndex
        let description = String(arrowStripped[..<descriptionEnd]).trimmingCharacters(in: .whitespaces)
        self.description = description
        self.physicalOp = Self.physicalOperation(from: description)
        self.logicalOp = Self.logicalOperation(from: description, fallback: physicalOp)

        self.totalSubtreeCost = Self.captureDouble(pattern: #"cost=([0-9]+(?:\.[0-9]+)?)"#, in: arrowStripped)
        self.estimateRows = Self.captureDouble(pattern: #"cost=[^)]*rows=([0-9]+(?:\.[0-9]+)?)"#, in: arrowStripped)

        if let actualMatch = arrowStripped.range(of: #"\(actual time=[^)]*rows=\d+ loops=\d+\)"#, options: .regularExpression) {
            let actualSegment = String(arrowStripped[actualMatch])
            self.actualElapsedMs = Self.captureDouble(pattern: #"actual time=[0-9]+(?:\.[0-9]+)?\.\.([0-9]+(?:\.[0-9]+)?)"#, in: actualSegment).map { Int($0.rounded()) }
            self.actualRows = Self.captureInt(pattern: #"rows=(\d+)"#, in: actualSegment)
            self.actualExecutions = Self.captureInt(pattern: #"loops=(\d+)"#, in: actualSegment)
        } else {
            self.actualElapsedMs = nil
            self.actualRows = nil
            self.actualExecutions = nil
        }
    }

    private static func physicalOperation(from description: String) -> String {
        let lowered = description.lowercased()
        switch lowered {
        case let value where value.hasPrefix("table scan"):
            return "Table Scan"
        case let value where value.hasPrefix("index lookup"):
            return "Index Lookup"
        case let value where value.hasPrefix("index range scan"):
            return "Range Scan"
        case let value where value.hasPrefix("index scan"):
            return "Index Scan"
        case let value where value.hasPrefix("nested loop"):
            return "Nested Loop"
        case let value where value.hasPrefix("filter"):
            return "Filter"
        case let value where value.hasPrefix("sort"):
            return "Sort"
        case let value where value.hasPrefix("aggregate"):
            return "Aggregate"
        default:
            return description
        }
    }

    private static func logicalOperation(from description: String, fallback: String) -> String {
        let lowered = description.lowercased()
        if let range = lowered.range(of: " on ") {
            return String(description[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        return fallback
    }

    private static func captureDouble(pattern: String, in text: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Double(text[valueRange])
    }

    private static func captureInt(pattern: String, in text: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Int(text[valueRange])
    }
}

private struct MutableNode {
    let parsed: ParsedLine
    var children: [MutableNode] = []

    init(_ parsed: ParsedLine) {
        self.parsed = parsed
    }

    func makeExecutionPlanNode() -> ExecutionPlanNode {
        let materializedChildren = children.map { $0.makeExecutionPlanNode() }
        return ExecutionPlanNode(
            id: parsed.index,
            physicalOp: parsed.physicalOp,
            logicalOp: parsed.logicalOp,
            estimateRows: parsed.estimateRows,
            estimateIO: nil,
            estimateCPU: nil,
            avgRowSize: nil,
            totalSubtreeCost: parsed.totalSubtreeCost,
            isParallel: false,
            estimatedExecutions: parsed.actualExecutions.map(Double.init),
            actualRows: parsed.actualRows,
            actualExecutions: parsed.actualExecutions,
            actualElapsedMs: parsed.actualElapsedMs,
            actualCPUMs: nil,
            children: materializedChildren,
            outputColumns: [],
            warnings: []
        )
    }
}
