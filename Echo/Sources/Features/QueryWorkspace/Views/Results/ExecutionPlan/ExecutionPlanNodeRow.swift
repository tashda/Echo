import SwiftUI

struct ExecutionPlanNodeRow: View {
    let node: ExecutionPlanNode
    let depth: Int
    let totalCost: Double
    @Binding var expandedNodes: Set<Int>

    private var isExpanded: Bool {
        expandedNodes.contains(node.id)
    }

    private var costPercent: Double {
        guard totalCost > 0, let opCost = node.operatorCost else { return 0 }
        return (opCost / totalCost) * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            nodeRow
            if isExpanded {
                ForEach(node.children, id: \.id) { child in
                    ExecutionPlanNodeRow(
                        node: child,
                        depth: depth + 1,
                        totalCost: totalCost,
                        expandedNodes: $expandedNodes
                    )
                }
            }
        }
    }

    private var nodeRow: some View {
        HStack(spacing: SpacingTokens.xxs) {
            // Indentation
            Spacer()
                .frame(width: CGFloat(depth) * 20)

            // Expand/collapse chevron
            if !node.children.isEmpty {
                Button {
                    if isExpanded {
                        expandedNodes.remove(node.id)
                    } else {
                        expandedNodes.insert(node.id)
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(TypographyTokens.compact)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .frame(width: 14)
                }
                .buttonStyle(.plain)
            } else {
                Spacer().frame(width: 14)
            }

            // Operator icon
            operatorIcon
                .frame(width: 16, height: 16)

            // Physical op name
            Text(node.physicalOp)
                .font(TypographyTokens.detail.weight(.medium))
                .lineLimit(1)

            // Logical op (if different)
            if node.logicalOp != node.physicalOp {
                Text("(\(node.logicalOp))")
                    .font(TypographyTokens.compact)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .lineLimit(1)
            }

            if node.isParallel {
                Image(systemName: "arrow.triangle.branch")
                    .font(TypographyTokens.compact)
                    .foregroundStyle(ColorTokens.Status.info)
                    .help("Parallel execution")
            }

            Spacer(minLength: SpacingTokens.sm)

            // Cost percentage bar
            costBar

            // Metrics
            metricsView
        }
        .padding(.vertical, SpacingTokens.xxs2)
        .padding(.horizontal, SpacingTokens.xs)
        .background(warningBackground)
        .contentShape(Rectangle())
    }

    private var operatorIcon: some View {
        let (iconName, color) = operatorIconInfo
        return Image(systemName: iconName)
            .font(TypographyTokens.label)
            .foregroundStyle(color)
    }

    private var operatorIconInfo: (String, Color) {
        let op = node.physicalOp.lowercased()
        if op.contains("scan") {
            return ("arrow.left.arrow.right", ColorTokens.Status.warning)
        } else if op.contains("seek") {
            return ("target", ColorTokens.Status.success)
        } else if op.contains("join") {
            return ("arrow.triangle.merge", ColorTokens.accent)
        } else if op.contains("sort") {
            return ("arrow.up.arrow.down", ColorTokens.Status.info)
        } else if op.contains("hash") {
            return ("number", ColorTokens.Status.info)
        } else if op.contains("spool") {
            return ("tray.2", ColorTokens.Text.tertiary)
        } else if op.contains("insert") || op.contains("update") || op.contains("delete") {
            return ("pencil", ColorTokens.Status.error)
        } else if op.contains("select") || op.contains("result") {
            return ("arrow.right.circle", ColorTokens.Text.secondary)
        } else {
            return ("gearshape", ColorTokens.Text.tertiary)
        }
    }

    private var costBar: some View {
        let pct = costPercent
        return HStack(spacing: SpacingTokens.xxs) {
            GeometryReader { geometry in
                let barWidth = geometry.size.width * min(pct / 100, 1.0)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ColorTokens.Text.quaternary.opacity(0.2))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(costColor(pct))
                        .frame(width: max(barWidth, pct > 0 ? 2 : 0))
                }
            }
            .frame(width: 60, height: 8)

            Text(String(format: "%.0f%%", pct))
                .font(TypographyTokens.compact.monospaced())
                .foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: 36, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var metricsView: some View {
        HStack(spacing: SpacingTokens.xs) {
            if let estRows = node.estimateRows {
                metricPill("Est", formatNumber(estRows))
            }
            if let actRows = node.actualRows {
                metricPill("Act", formatNumber(Double(actRows)))
            }
            if let elapsed = node.actualElapsedMs {
                metricPill("Time", "\(elapsed)ms")
            }
        }
        .frame(minWidth: 120, alignment: .trailing)
    }

    private func metricPill(_ label: String, _ value: String) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(TypographyTokens.compact)
                .foregroundStyle(ColorTokens.Text.quaternary)
            Text(value)
                .font(TypographyTokens.compact.monospaced())
                .foregroundStyle(ColorTokens.Text.secondary)
        }
    }

    @ViewBuilder
    private var warningBackground: some View {
        if !node.warnings.isEmpty {
            ColorTokens.Status.warning.opacity(0.08)
        } else {
            Color.clear
        }
    }

    private func costColor(_ pct: Double) -> Color {
        if pct > 50 { return ColorTokens.Status.error }
        if pct > 20 { return ColorTokens.Status.warning }
        if pct > 5 { return ColorTokens.accent }
        return ColorTokens.Status.success
    }

    private func formatNumber(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", value / 1_000)
        } else if value == value.rounded() {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}
