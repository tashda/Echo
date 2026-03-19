import SwiftUI

/// A single operator card in the graphical execution plan flow.
/// Shows icon, operator name, object reference, cost %, and estimated rows.
struct ExecutionPlanNodeCard: View {
    let node: ExecutionPlanNode
    let totalCost: Double
    let isSelected: Bool
    let isHovered: Bool

    @State private var showPopover = false

    private var costPercent: Double {
        guard totalCost > 0, let opCost = node.operatorCost else { return 0 }
        return (opCost / totalCost) * 100
    }

    /// Extract the primary object name (table/index) from output columns.
    /// Output columns are strings — may contain dotted names like "[schema].[table].[column]".
    private var objectName: String? {
        let tables = Set(node.outputColumns.compactMap { col -> String? in
            // Columns may be bracket-qualified: [dbo].[Users].[Id]
            let cleaned = col.replacingOccurrences(of: "[", with: "")
                .replacingOccurrences(of: "]", with: "")
            let parts = cleaned.split(separator: ".")
            guard parts.count >= 2 else { return nil }
            // The table is the second-to-last part
            return String(parts[parts.count - 2])
        })
        return tables.first
    }

    var body: some View {
        VStack(spacing: 2) {
            // Icon
            operatorIcon
                .frame(width: 18, height: 18)

            // Operator name
            Text(node.physicalOp)
                .font(TypographyTokens.compact.weight(.medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // Object name (table/index being accessed)
            if let obj = objectName {
                Text(obj)
                    .font(TypographyTokens.compact)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .lineLimit(1)
            }

            // Cost percentage — prominent when significant
            Text(formatCostLabel())
                .font(TypographyTokens.compact.monospaced().weight(.semibold))
                .foregroundStyle(costColor)
        }
        .padding(.horizontal, SpacingTokens.xs)
        .padding(.vertical, SpacingTokens.xs2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cardBackgroundColor, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(borderColor, lineWidth: isSelected ? 1.5 : 0.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            ExecutionPlanNodeDetail(node: node, totalCost: totalCost)
        }
        .onTapGesture(count: 2) { showPopover.toggle() }
        .onTapGesture(count: 1) { /* single tap handled by parent for selection */ }
        .help("\(node.physicalOp) — double-click for details")
    }

    // MARK: - Formatting

    private func formatCostLabel() -> String {
        let pct = costPercent
        if pct < 1 { return "< 1%" }
        return String(format: "%.0f%%", pct)
    }

    // MARK: - Styling

    private var cardBackgroundColor: Color {
        if !node.warnings.isEmpty {
            return ColorTokens.Status.warning.opacity(0.1)
        } else if isSelected {
            return ColorTokens.accent.opacity(0.08)
        } else {
            return ColorTokens.Background.secondary
        }
    }

    private var borderColor: Color {
        if isSelected { return ColorTokens.accent }
        if !node.warnings.isEmpty { return ColorTokens.Status.warning.opacity(0.5) }
        return ColorTokens.Text.quaternary.opacity(0.25)
    }

    private var costColor: Color {
        let pct = costPercent
        if pct > 50 { return ColorTokens.Status.error }
        if pct > 20 { return ColorTokens.Status.warning }
        if pct > 5 { return ColorTokens.accent }
        return ColorTokens.Text.secondary
    }

    private var operatorIcon: some View {
        let (iconName, color) = operatorIconInfo
        return Image(systemName: iconName)
            .font(.system(size: 13, weight: .medium))
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
        } else if op.contains("select") || op.contains("result") || op.contains("top") {
            return ("arrow.right.circle", ColorTokens.Text.secondary)
        } else if op.contains("aggregate") || op.contains("stream") || op.contains("compute") {
            return ("sum", ColorTokens.Status.info)
        } else if op.contains("filter") {
            return ("line.3.horizontal.decrease", ColorTokens.accent)
        } else if op.contains("index") {
            return ("list.bullet.rectangle", ColorTokens.Status.success)
        } else {
            return ("gearshape", ColorTokens.Text.tertiary)
        }
    }
}
