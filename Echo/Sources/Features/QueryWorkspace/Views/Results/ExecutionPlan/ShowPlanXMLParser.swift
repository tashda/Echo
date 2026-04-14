import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import SQLServerKit

/// Local copy of the ShowPlan XML parser.
/// Echo currently resolves a SQLServerKit revision where this type isn't public.
final class ShowPlanXMLParser: NSObject, XMLParserDelegate, @unchecked Sendable {
    static func parse(xml: String) throws -> ShowPlan {
        let normalized = xml.replacingOccurrences(of: "encoding=\"utf-16\"", with: "encoding=\"utf-8\"")
        guard let data = normalized.data(using: .utf8) else {
            throw ShowPlanParseError.invalidXML("Unable to encode XML as UTF-8")
        }

        let handler = ShowPlanXMLParser(rawXML: xml)
        let parser = XMLParser(data: data)
        parser.delegate = handler
        parser.shouldProcessNamespaces = true
        parser.shouldReportNamespacePrefixes = false

        guard parser.parse() else {
            if let error = handler.parseError {
                throw error
            }
            if let parserError = parser.parserError {
                throw ShowPlanParseError.invalidXML(parserError.localizedDescription)
            }
            throw ShowPlanParseError.invalidXML("Unknown parse error")
        }

        if let error = handler.parseError {
            throw error
        }

        return ShowPlan(
            statements: handler.statements,
            buildVersion: handler.buildVersion,
            xml: xml
        )
    }

    private let rawXML: String
    private var buildVersion: String?
    private var statements: [ShowPlanStatement] = []
    private var parseError: ShowPlanParseError?
    private var elementStack: [ParseContext] = []

    private var currentStatementText: String = ""
    private var currentStatementType: String = ""
    private var currentStatementSubTreeCost: Double?
    private var currentStatementEstRows: Double?
    private var currentQueryHash: String?
    private var currentQueryPlanHash: String?
    private var currentOptimizationLevel: String?

    private var currentCachedPlanSize: Int?
    private var currentCompileTime: Int?
    private var currentCompileCPU: Int?

    private var operatorStack: [OperatorBuilder] = []
    private var rootOperator: ShowPlanOperator?

    private var currentMissingIndexes: [ShowPlanMissingIndex] = []
    private var currentMissingIndexImpact: Double?
    private var currentMissingIndexDatabase: String?
    private var currentMissingIndexSchema: String?
    private var currentMissingIndexTable: String?
    private var currentMissingEqualityCols: [String] = []
    private var currentMissingInequalityCols: [String] = []
    private var currentMissingIncludeCols: [String] = []
    private var currentMissingColumnUsage: String?

    private var currentOutputColumns: [ShowPlanColumnReference] = []
    private var currentWarnings: [String] = []
    private var currentActualRows: Int?
    private var currentActualExecutions: Int?
    private var currentActualElapsedMs: Int?
    private var currentActualCPUMs: Int?

    private init(rawXML: String) {
        self.rawXML = rawXML
    }

    private enum ParseContext {
        case showPlanXML
        case batchSequence
        case batch
        case statements
        case stmtSimple
        case stmtCond
        case queryPlan
        case relOp
        case outputList
        case columnReference
        case runTimeInformation
        case runTimeCountersPerThread
        case warnings
        case missingIndexes
        case missingIndexGroup
        case missingIndex
        case columnGroup
        case column
        case other(String)
    }

    private final class OperatorBuilder {
        var nodeId: Int = 0
        var physicalOp: String = ""
        var logicalOp: String = ""
        var estimateRows: Double?
        var estimateIO: Double?
        var estimateCPU: Double?
        var avgRowSize: Int?
        var totalSubtreeCost: Double?
        var isParallel: Bool = false
        var estimatedExecutions: Double?
        var actualRows: Int?
        var actualExecutions: Int?
        var actualElapsedMs: Int?
        var actualCPUMs: Int?
        var children: [ShowPlanOperator] = []
        var outputColumns: [ShowPlanColumnReference] = []
        var warnings: [String] = []

        func build() -> ShowPlanOperator {
            ShowPlanOperator(
                nodeId: nodeId,
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
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes attributeDict: [String: String]
    ) {
        switch elementName {
        case "ShowPlanXML":
            buildVersion = attributeDict["Build"] ?? attributeDict["BuildVersion"]
            elementStack.append(.showPlanXML)

        case "BatchSequence":
            elementStack.append(.batchSequence)

        case "Batch":
            elementStack.append(.batch)

        case "Statements":
            elementStack.append(.statements)

        case "StmtSimple":
            beginStatement(attributes: attributeDict, fallbackType: "")
            elementStack.append(.stmtSimple)

        case "StmtCond":
            beginStatement(attributes: attributeDict, fallbackType: "COND")
            elementStack.append(.stmtCond)

        case "QueryPlan":
            currentCachedPlanSize = attributeDict["CachedPlanSize"].flatMap(Int.init)
            currentCompileTime = attributeDict["CompileTime"].flatMap(Int.init)
            currentCompileCPU = attributeDict["CompileCPU"].flatMap(Int.init)
            elementStack.append(.queryPlan)

        case "RelOp":
            beginOperator(attributes: attributeDict)
            elementStack.append(.relOp)

        case "OutputList":
            currentOutputColumns = []
            elementStack.append(.outputList)

        case "ColumnReference":
            handleColumnReference(attributes: attributeDict)
            elementStack.append(.columnReference)

        case "RunTimeInformation":
            currentActualRows = 0
            currentActualExecutions = 0
            currentActualElapsedMs = 0
            currentActualCPUMs = 0
            elementStack.append(.runTimeInformation)

        case "RunTimeCountersPerThread":
            accumulateThreadCounters(attributes: attributeDict)
            elementStack.append(.runTimeCountersPerThread)

        case "Warnings":
            currentWarnings = []
            elementStack.append(.warnings)

        case "SpillToTempDb":
            if let spill = attributeDict["SpillLevel"] {
                currentWarnings.append("SpillToTempDb (Level \(spill))")
            } else {
                currentWarnings.append("SpillToTempDb")
            }

        case "NoJoinPredicate":
            currentWarnings.append("NoJoinPredicate")

        case "ColumnsWithNoStatistics":
            currentWarnings.append("ColumnsWithNoStatistics")

        case "MissingIndexes":
            elementStack.append(.missingIndexes)

        case "MissingIndexGroup":
            currentMissingIndexImpact = attributeDict["Impact"].flatMap(Double.init)
            elementStack.append(.missingIndexGroup)

        case "MissingIndex":
            currentMissingIndexDatabase = attributeDict["Database"]?.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            currentMissingIndexSchema = attributeDict["Schema"]?.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            currentMissingIndexTable = attributeDict["Table"]?.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            currentMissingEqualityCols = []
            currentMissingInequalityCols = []
            currentMissingIncludeCols = []
            elementStack.append(.missingIndex)

        case "ColumnGroup":
            currentMissingColumnUsage = attributeDict["Usage"]
            elementStack.append(.columnGroup)

        case "Column":
            let colName = attributeDict["Name"] ?? ""
            if !colName.isEmpty {
                appendMissingIndexColumn(named: colName)
            }
            elementStack.append(.column)

        default:
            elementStack.append(.other(elementName))
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        guard !elementStack.isEmpty else { return }
        _ = elementStack.removeLast()

        switch elementName {
        case "StmtSimple", "StmtCond":
            let statement = ShowPlanStatement(
                statementText: currentStatementText,
                statementType: currentStatementType,
                statementSubTreeCost: currentStatementSubTreeCost,
                statementEstRows: currentStatementEstRows,
                queryHash: currentQueryHash,
                queryPlanHash: currentQueryPlanHash,
                optimizationLevel: currentOptimizationLevel,
                queryPlan: buildQueryPlan()
            )
            statements.append(statement)
            currentCachedPlanSize = nil
            currentCompileTime = nil
            currentCompileCPU = nil
            rootOperator = nil

        case "RelOp":
            finishOperator()

        case "MissingIndex":
            let missingIndex = ShowPlanMissingIndex(
                impact: currentMissingIndexImpact,
                database: currentMissingIndexDatabase,
                schema: currentMissingIndexSchema,
                table: currentMissingIndexTable,
                equalityColumns: currentMissingEqualityCols,
                inequalityColumns: currentMissingInequalityCols,
                includeColumns: currentMissingIncludeCols
            )
            currentMissingIndexes.append(missingIndex)

        case "ColumnGroup":
            currentMissingColumnUsage = nil

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = ShowPlanParseError.invalidXML(parseError.localizedDescription)
    }

    private func beginStatement(attributes: [String: String], fallbackType: String) {
        currentStatementText = attributes["StatementText"] ?? ""
        currentStatementType = attributes["StatementType"] ?? fallbackType
        currentStatementSubTreeCost = attributes["StatementSubTreeCost"].flatMap(Double.init)
        currentStatementEstRows = attributes["StatementEstRows"].flatMap(Double.init)
        currentQueryHash = attributes["QueryHash"]
        currentQueryPlanHash = attributes["QueryPlanHash"]
        currentOptimizationLevel = attributes["StatementOptmLevel"]
        rootOperator = nil
        currentMissingIndexes = []
    }

    private func beginOperator(attributes: [String: String]) {
        let builder = OperatorBuilder()
        builder.nodeId = attributes["NodeId"].flatMap(Int.init) ?? 0
        builder.physicalOp = attributes["PhysicalOp"] ?? ""
        builder.logicalOp = attributes["LogicalOp"] ?? ""
        builder.estimateRows = attributes["EstimateRows"].flatMap(Double.init)
        builder.estimateIO = attributes["EstimateIO"].flatMap(Double.init)
        builder.estimateCPU = attributes["EstimateCPU"].flatMap(Double.init)
        builder.avgRowSize = attributes["AvgRowSize"].flatMap(Int.init)
        builder.totalSubtreeCost = attributes["EstimatedTotalSubtreeCost"].flatMap(Double.init)
        builder.isParallel = attributes["Parallel"] == "1" || attributes["Parallel"] == "true"
        builder.estimatedExecutions = attributes["EstimatedExecutionMode"].flatMap(Double.init)
            ?? attributes["EstimateExecutions"].flatMap(Double.init)
        currentOutputColumns = []
        currentWarnings = []
        currentActualRows = nil
        currentActualExecutions = nil
        currentActualElapsedMs = nil
        currentActualCPUMs = nil
        operatorStack.append(builder)
    }

    private func handleColumnReference(attributes: [String: String]) {
        let colRef = ShowPlanColumnReference(
            database: attributes["Database"]?.trimmingCharacters(in: CharacterSet(charactersIn: "[]")),
            schema: attributes["Schema"]?.trimmingCharacters(in: CharacterSet(charactersIn: "[]")),
            table: attributes["Table"]?.trimmingCharacters(in: CharacterSet(charactersIn: "[]")),
            column: attributes["Column"] ?? ""
        )

        guard let top = elementStack.last else { return }
        switch top {
        case .outputList:
            currentOutputColumns.append(colRef)
        case .columnGroup, .column:
            let colName = attributes["Column"] ?? ""
            if !colName.isEmpty {
                appendMissingIndexColumn(named: colName)
            }
        default:
            break
        }
    }

    private func appendMissingIndexColumn(named column: String) {
        switch currentMissingColumnUsage {
        case "EQUALITY":
            currentMissingEqualityCols.append(column)
        case "INEQUALITY":
            currentMissingInequalityCols.append(column)
        case "INCLUDE":
            currentMissingIncludeCols.append(column)
        default:
            break
        }
    }

    private func accumulateThreadCounters(attributes: [String: String]) {
        if let rows = attributes["ActualRows"].flatMap(Int.init) {
            currentActualRows = (currentActualRows ?? 0) + rows
        }
        if let executions = attributes["ActualExecutions"].flatMap(Int.init) {
            currentActualExecutions = (currentActualExecutions ?? 0) + executions
        }
        if let elapsed = attributes["ActualElapsedms"].flatMap(Int.init) {
            currentActualElapsedMs = max(currentActualElapsedMs ?? 0, elapsed)
        }
        if let cpu = attributes["ActualCPUms"].flatMap(Int.init) {
            currentActualCPUMs = (currentActualCPUMs ?? 0) + cpu
        }
    }

    private func buildQueryPlan() -> ShowPlanQueryPlan? {
        guard rootOperator != nil || !currentMissingIndexes.isEmpty ||
                currentCachedPlanSize != nil || currentCompileTime != nil else {
            return nil
        }

        return ShowPlanQueryPlan(
            cachedPlanSize: currentCachedPlanSize,
            compileTime: currentCompileTime,
            compileCPU: currentCompileCPU,
            rootOperator: rootOperator,
            missingIndexes: currentMissingIndexes
        )
    }

    private func finishOperator() {
        guard let builder = operatorStack.popLast() else { return }
        builder.outputColumns = currentOutputColumns
        builder.warnings = currentWarnings
        builder.actualRows = currentActualRows
        builder.actualExecutions = currentActualExecutions
        builder.actualElapsedMs = currentActualElapsedMs
        builder.actualCPUMs = currentActualCPUMs

        let op = builder.build()
        if let parent = operatorStack.last {
            parent.children.append(op)
        } else {
            rootOperator = op
        }

        currentOutputColumns = []
        currentWarnings = []
        currentActualRows = nil
        currentActualExecutions = nil
        currentActualElapsedMs = nil
        currentActualCPUMs = nil
    }
}

enum ShowPlanParseError: Error, Sendable {
    case invalidXML(String)
}
