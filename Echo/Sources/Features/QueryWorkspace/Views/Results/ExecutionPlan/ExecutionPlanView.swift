import SwiftUI

struct ExecutionPlanView: View {
    let plan: ExecutionPlanData
    @State private var selectedTab: PlanTab = .flow
    @State private var selectedNodeID: Int?

    /// Whether this plan contains MSSQL ShowPlanXML or Postgres text output.
    var isXMLPlan: Bool {
        guard let raw = plan.xml else { return false }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<")
    }

    enum PlanTab: Hashable {
        case flow
        case rawPlan
        case missingIndexes
        case compare
    }

    var body: some View {
        VStack(spacing: 0) {
            planToolbar
            Divider()
            planContent
        }
    }

    private var planToolbar: some View {
        HStack(spacing: SpacingTokens.sm) {
            Picker("View", selection: $selectedTab) {
                Text("Execution Plan").tag(PlanTab.flow)
                if plan.xml != nil {
                    Text(isXMLPlan ? "XML" : "Raw Plan").tag(PlanTab.rawPlan)
                }
                if !plan.missingIndexes.isEmpty {
                    Text("Missing Indexes (\(plan.missingIndexes.count))").tag(PlanTab.missingIndexes)
                }
                Text("Compare").tag(PlanTab.compare)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)

            Spacer()

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
        case .flow:
            flowView
        case .rawPlan:
            rawPlanView
        case .missingIndexes:
            missingIndexesView
        case .compare:
            ExecutionPlanComparisonView(currentPlan: plan)
        }
    }

    private var flowView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(plan.statements.indices, id: \.self) { stmtIdx in
                let stmt = plan.statements[stmtIdx]
                if plan.statements.count > 1 {
                    statementHeader(stmt, index: stmtIdx)
                }
                if let root = stmt.queryPlan?.rootOperator {
                    ExecutionPlanFlowView(
                        root: root,
                        totalCost: stmt.subtreeCost ?? root.totalSubtreeCost ?? 1,
                        selectedNodeID: $selectedNodeID
                    )
                }
            }
        }
    }

    private func statementHeader(_ stmt: ExecutionPlanStatement, index: Int) -> some View {
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
            Spacer()
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xs)
        .background(ColorTokens.Background.secondary)
    }

    private var rawPlanView: some View {
        ScrollView {
            Text(plan.xml ?? "No plan output available")
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

    private func formatCost(_ cost: Double) -> String {
        if cost < 0.01 {
            return String(format: "%.6f", cost)
        }
        return String(format: "%.4f", cost)
    }
}
