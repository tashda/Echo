import SwiftUI

/// Rich detail popover shown when double-clicking an operator card.
/// Displays all available metrics for the selected operator.
struct ExecutionPlanNodeDetail: View {
    let node: ExecutionPlanNode
    let totalCost: Double

    private var costPercent: Double {
        guard totalCost > 0, let opCost = node.operatorCost else { return 0 }
        return (opCost / totalCost) * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            // Header
            HStack(spacing: SpacingTokens.xs) {
                Text(node.physicalOp)
                    .font(TypographyTokens.standard.weight(.semibold))
                if node.logicalOp != node.physicalOp {
                    Text("(\(node.logicalOp))")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
                if node.isParallel {
                    Image(systemName: "arrow.triangle.branch")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Status.info)
                }
            }

            Divider()

            // Cost section
            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                detailRow("Operator Cost", String(format: "%.0f%%", costPercent))
                if let subtree = node.totalSubtreeCost {
                    detailRow("Total Cost", formatCost(subtree))
                }
                if let io = node.estimateIO {
                    detailRow("Startup Cost", formatCost(io))
                }
                if let cpu = node.estimateCPU {
                    detailRow("Run Cost", formatCost(cpu))
                }
            }

            // Row estimates
            if node.estimateRows != nil || node.actualRows != nil {
                Divider()
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    if let est = node.estimateRows {
                        detailRow("Estimated Rows", formatNumber(est))
                    }
                    if let act = node.actualRows {
                        detailRow("Actual Rows", formatNumber(Double(act)))
                    }
                    if let estExec = node.estimatedExecutions {
                        detailRow("Est. Executions", formatNumber(estExec))
                    }
                    if let actExec = node.actualExecutions {
                        detailRow("Actual Executions", formatNumber(Double(actExec)))
                    }
                }
            }

            // Timing (actual plans)
            if node.actualElapsedMs != nil || node.actualCPUMs != nil {
                Divider()
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    if let elapsed = node.actualElapsedMs {
                        detailRow("Elapsed Time", "\(elapsed)ms")
                    }
                    if let cpu = node.actualCPUMs {
                        detailRow("CPU Time", "\(cpu)ms")
                    }
                }
            }

            // Row size
            if let avgSize = node.avgRowSize {
                Divider()
                detailRow("Avg Row Size", "\(avgSize) B")
            }

            // Output columns
            if !node.outputColumns.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    Text("Output Columns")
                        .font(TypographyTokens.compact)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                    Text(node.outputColumns.joined(separator: ", "))
                        .font(TypographyTokens.compact.monospaced())
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .textSelection(.enabled)
                }
            }

            // Warnings
            if !node.warnings.isEmpty {
                Divider()
                ForEach(node.warnings, id: \.self) { warning in
                    HStack(spacing: SpacingTokens.xxs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(ColorTokens.Status.warning)
                            .font(TypographyTokens.compact)
                        Text(warning)
                            .font(TypographyTokens.compact)
                            .foregroundStyle(ColorTokens.Status.warning)
                    }
                }
            }
        }
        .padding(SpacingTokens.md)
        .frame(minWidth: 240, maxWidth: 320)
    }

    // MARK: - Components

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(TypographyTokens.compact)
                .foregroundStyle(ColorTokens.Text.tertiary)
            Spacer()
            Text(value)
                .font(TypographyTokens.compact.monospaced())
                .foregroundStyle(ColorTokens.Text.primary)
        }
    }

    // MARK: - Formatting

    private func formatCost(_ cost: Double) -> String {
        if cost < 0.01 { return String(format: "%.6f", cost) }
        return String(format: "%.4f", cost)
    }

    private func formatNumber(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        if value >= 1_000 { return String(format: "%.1fK", value / 1_000) }
        if value == value.rounded() { return String(format: "%.0f", value) }
        return String(format: "%.1f", value)
    }
}
