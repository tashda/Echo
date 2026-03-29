import SwiftUI
import AppKit
import UniformTypeIdentifiers
import SQLServerKit

/// Side-by-side comparison of two execution plans.
/// Loads a second plan from a saved .sqlplan or .xml file.
struct ExecutionPlanComparisonView: View {
    let currentPlan: ExecutionPlanData
    @State private var comparedPlan: ExecutionPlanData?
    @State private var comparedPlanFileName: String?
    @State private var errorMessage: String?

    var body: some View {
        if comparedPlan != nil {
            comparisonContent
        } else {
            loadPrompt
        }
    }

    private var loadPrompt: some View {
        VStack(spacing: SpacingTokens.md) {
            Image(systemName: "arrow.left.arrow.right")
                .font(TypographyTokens.iconDisplay)
                .foregroundStyle(ColorTokens.Text.tertiary)

            Text("Compare Execution Plans")
                .font(TypographyTokens.headline)

            Text("Load a saved ShowPlan XML file to compare against the current plan.")
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Button("Open Plan XML") {
                loadPlanFile()
            }
            .buttonStyle(.bordered)

            if let error = errorMessage {
                Text(error)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Status.error)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var comparisonContent: some View {
        VStack(spacing: 0) {
            summaryBar
            Divider()
            HSplitView {
                currentPlanColumn
                comparedPlanColumn
            }
        }
    }

    private var summaryBar: some View {
        HStack(spacing: SpacingTokens.lg) {
            if let cost = currentPlan.statements.first?.subtreeCost {
                HStack(spacing: SpacingTokens.xxs) {
                    Text("Current:")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                    Text(String(format: "%.4f", cost))
                        .font(TypographyTokens.detail.weight(.medium).monospacedDigit())
                }
            }

            if let compared = comparedPlan, let cost = compared.statements.first?.subtreeCost {
                HStack(spacing: SpacingTokens.xxs) {
                    Text("Compared:")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                    Text(String(format: "%.4f", cost))
                        .font(TypographyTokens.detail.weight(.medium).monospacedDigit())
                }
            }

            if let fileName = comparedPlanFileName {
                Text(fileName)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            Spacer()

            Button("Change File") {
                loadPlanFile()
            }
            .controlSize(.small)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
        .background(ColorTokens.Background.secondary)
    }

    private var currentPlanColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Current Plan")
                .font(TypographyTokens.headline)
                .padding(SpacingTokens.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ColorTokens.Background.secondary)

            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading) {
                    ForEach(currentPlan.statements.indices, id: \.self) { idx in
                        let stmt = currentPlan.statements[idx]
                        if let root = stmt.queryPlan?.rootOperator {
                            ExecutionPlanFlowView(
                                root: root,
                                totalCost: stmt.subtreeCost ?? root.totalSubtreeCost ?? 1,
                                selectedNodeID: .constant(nil)
                            )
                        }
                    }
                }
            }
        }
        .frame(minWidth: 300)
    }

    private var comparedPlanColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Compared Plan")
                .font(TypographyTokens.headline)
                .padding(SpacingTokens.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ColorTokens.Background.secondary)

            if let compared = comparedPlan {
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading) {
                        ForEach(compared.statements.indices, id: \.self) { idx in
                            let stmt = compared.statements[idx]
                            if let root = stmt.queryPlan?.rootOperator {
                                ExecutionPlanFlowView(
                                    root: root,
                                    totalCost: stmt.subtreeCost ?? root.totalSubtreeCost ?? 1,
                                    selectedNodeID: .constant(nil)
                                )
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 300)
    }

    private func loadPlanFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "sqlplan") ?? .xml, .xml]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        errorMessage = nil
        do {
            let xmlString = try String(contentsOf: url, encoding: .utf8)
            let parsed = try parseXMLPlan(xmlString)
            comparedPlan = parsed
            comparedPlanFileName = url.lastPathComponent
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func parseXMLPlan(_ xml: String) throws -> ExecutionPlanData {
        let showPlan = try ShowPlanXMLParser.parse(xml: xml)
        return ExecutionPlanData(
            statements: showPlan.statements.map(convertStatement),
            xml: xml
        )
    }

    private func convertStatement(_ stmt: ShowPlanStatement) -> ExecutionPlanStatement {
        ExecutionPlanStatement(
            statementText: stmt.statementText,
            statementType: stmt.statementType,
            subtreeCost: stmt.statementSubTreeCost,
            estimatedRows: stmt.statementEstRows,
            optimizationLevel: stmt.optimizationLevel,
            queryPlan: stmt.queryPlan.map(convertQueryPlan)
        )
    }

    private func convertQueryPlan(_ qp: ShowPlanQueryPlan) -> ExecutionPlanQueryPlan {
        ExecutionPlanQueryPlan(
            cachedPlanSize: qp.cachedPlanSize,
            compileTime: qp.compileTime,
            compileCPU: qp.compileCPU,
            rootOperator: qp.rootOperator.map(convertOperator),
            missingIndexes: qp.missingIndexes.map(convertMissingIndex)
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
