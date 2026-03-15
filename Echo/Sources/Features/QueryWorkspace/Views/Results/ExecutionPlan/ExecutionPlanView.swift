import SwiftUI

struct ExecutionPlanView: View {
    let plan: ExecutionPlanData
    @State private var selectedTab: PlanTab = .tree
    @State private var expandedNodes: Set<Int> = []
    @State private var isInitialized = false

    enum PlanTab: Hashable {
        case tree
        case xml
        case missingIndexes
    }

    var body: some View {
        VStack(spacing: 0) {
            planToolbar
            Divider()
            planContent
        }
        .onAppear {
            guard !isInitialized else { return }
            isInitialized = true
            expandAllNodes()
        }
    }

    private var planToolbar: some View {
        HStack(spacing: SpacingTokens.sm) {
            Picker("View", selection: $selectedTab) {
                Text("Operator Tree").tag(PlanTab.tree)
                Text("XML").tag(PlanTab.xml)
                if !plan.missingIndexes.isEmpty {
                    Text("Missing Indexes (\(plan.missingIndexes.count))").tag(PlanTab.missingIndexes)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)

            Spacer()

            if selectedTab == .tree {
                Button {
                    expandAllNodes()
                } label: {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                }
                .buttonStyle(.borderless)
                .help("Expand All")

                Button {
                    expandedNodes.removeAll()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.borderless)
                .help("Collapse All")
            }

            if let stmt = plan.statements.first, let cost = stmt.subtreeCost {
                Text("Cost: \(formatCost(cost))")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xs)
        .background(ColorTokens.Background.secondary)
    }

    @ViewBuilder
    private var planContent: some View {
        switch selectedTab {
        case .tree:
            treeView
        case .xml:
            xmlView
        case .missingIndexes:
            missingIndexesView
        }
    }

    private var treeView: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(plan.statements.indices, id: \.self) { stmtIdx in
                    let stmt = plan.statements[stmtIdx]
                    if plan.statements.count > 1 {
                        statementHeader(stmt, index: stmtIdx)
                    }
                    if let root = stmt.queryPlan?.rootOperator {
                        ExecutionPlanNodeRow(
                            node: root,
                            depth: 0,
                            totalCost: stmt.subtreeCost ?? root.totalSubtreeCost ?? 1,
                            expandedNodes: $expandedNodes
                        )
                    }
                }
            }
            .padding(SpacingTokens.sm)
        }
    }

    private func statementHeader(_ stmt: ExecutionPlanStatement, index: Int) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            HStack(spacing: SpacingTokens.xs) {
                Text("Statement \(index + 1)")
                    .font(TypographyTokens.caption.weight(.semibold))
                if let level = stmt.optimizationLevel {
                    Text(level)
                        .font(TypographyTokens.compact)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
                if let cost = stmt.subtreeCost {
                    Text("Cost: \(formatCost(cost))")
                        .font(TypographyTokens.compact)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            Text(stmt.statementText.prefix(200))
                .font(TypographyTokens.detail.monospaced())
                .foregroundStyle(ColorTokens.Text.secondary)
                .lineLimit(2)
        }
        .padding(.bottom, SpacingTokens.xs)
    }

    private var xmlView: some View {
        ScrollView {
            Text(plan.xml ?? "No XML available")
                .font(TypographyTokens.detail.monospaced())
                .textSelection(.enabled)
                .padding(SpacingTokens.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var missingIndexesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                ForEach(plan.missingIndexes) { idx in
                    ExecutionPlanMissingIndexRow(index: idx)
                }
            }
            .padding(SpacingTokens.sm)
        }
    }

    private func expandAllNodes() {
        expandedNodes.removeAll()
        for stmt in plan.statements {
            if let root = stmt.queryPlan?.rootOperator {
                collectNodeIDs(root)
            }
        }
    }

    private func collectNodeIDs(_ node: ExecutionPlanNode) {
        if !node.children.isEmpty {
            expandedNodes.insert(node.id)
            for child in node.children {
                collectNodeIDs(child)
            }
        }
    }

    private func formatCost(_ cost: Double) -> String {
        if cost < 0.01 {
            return String(format: "%.6f", cost)
        }
        return String(format: "%.4f", cost)
    }
}
