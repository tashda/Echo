import SwiftUI

/// Graphical execution plan view showing operators as connected cards flowing right-to-left.
/// Mirrors SSMS layout: result at left, data sources at right, arrows show data flow direction.
struct ExecutionPlanFlowView: View {
    let root: ExecutionPlanNode
    let totalCost: Double
    @Binding var selectedNodeID: Int?

    @State private var nodeFrames: [Int: CGRect] = [:]

    let nodeWidth: CGFloat = 150
    let nodeHeight: CGFloat = 80
    let hGap: CGFloat = 56
    let vGap: CGFloat = 12

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            let tree = buildLayout(root, depth: 0, yOffset: 0)
            ZStack(alignment: .topLeading) {
                // Arrows behind nodes
                ForEach(collectArrows(tree), id: \.id) { arrow in
                    ExecutionPlanArrowShape(from: arrow.from, to: arrow.to)
                        .stroke(
                            arrowColor(cost: arrow.costPercent),
                            style: StrokeStyle(
                                lineWidth: arrowWidth(rows: arrow.rows),
                                lineCap: .round
                            )
                        )

                    // Row count label
                    if arrow.rows > 0 {
                        Text(formatRows(arrow.rows))
                            .font(TypographyTokens.compact.monospaced())
                            .foregroundStyle(ColorTokens.Text.tertiary)
                            .position(
                                x: (arrow.from.x + arrow.to.x) / 2,
                                y: (arrow.from.y + arrow.to.y) / 2 - 10
                            )
                    }

                    // Arrowhead (pointing left toward parent)
                    ExecutionPlanArrowheadShape(at: arrow.to, size: arrowWidth(rows: arrow.rows) + 4)
                        .fill(arrowColor(cost: arrow.costPercent))
                }

                // Nodes
                ForEach(collectLayoutNodes(tree), id: \.node.id) { item in
                    ExecutionPlanNodeCard(
                        node: item.node,
                        totalCost: totalCost,
                        isSelected: selectedNodeID == item.node.id,
                        isHovered: false
                    )
                    .frame(width: nodeWidth, height: nodeHeight)
                    .onTapGesture { selectedNodeID = item.node.id }
                    .offset(x: item.rect.minX, y: item.rect.minY)
                }
            }
            .frame(
                width: treeWidth(tree) + SpacingTokens.lg,
                height: treeHeight(tree) + SpacingTokens.lg,
                alignment: .topLeading
            )
            .padding(SpacingTokens.md)
        }
        .background(ColorTokens.Background.primary)
    }

    // MARK: - Arrow styling

    private func arrowWidth(rows: Double) -> CGFloat {
        if rows <= 0 { return 1.5 }
        let logScale = log10(max(rows, 1)) / 6.0
        return max(1.5, min(logScale * 6, 6))
    }

    private func arrowColor(cost: Double) -> Color {
        if cost > 50 { return ColorTokens.Status.error.opacity(0.7) }
        if cost > 20 { return ColorTokens.Status.warning.opacity(0.6) }
        return ColorTokens.Text.quaternary.opacity(0.5)
    }

    private func formatRows(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        if value >= 1_000 { return String(format: "%.1fK", value / 1_000) }
        if value == value.rounded() { return String(format: "%.0f", value) }
        return String(format: "%.1f", value)
    }
}
