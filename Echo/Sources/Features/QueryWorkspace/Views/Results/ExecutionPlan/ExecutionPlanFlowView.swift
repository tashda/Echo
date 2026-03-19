import SwiftUI

/// Graphical execution plan view showing operators as connected cards flowing right-to-left.
/// Mirrors SSMS layout: result at left, data sources at right, arrows show data flow direction.
struct ExecutionPlanFlowView: View {
    let root: ExecutionPlanNode
    let totalCost: Double
    @Binding var selectedNodeID: Int?

    @State private var nodeFrames: [Int: CGRect] = [:]

    private let nodeWidth: CGFloat = 150
    private let nodeHeight: CGFloat = 80
    private let hGap: CGFloat = 56
    private let vGap: CGFloat = 12

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            let tree = buildLayout(root, depth: 0, yOffset: 0)
            ZStack(alignment: .topLeading) {
                // Arrows behind nodes
                ForEach(collectArrows(tree), id: \.id) { arrow in
                    ArrowShape(from: arrow.from, to: arrow.to)
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
                    ArrowheadShape(at: arrow.to, size: arrowWidth(rows: arrow.rows) + 4)
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

    // MARK: - Layout Tree

    private struct LayoutNode {
        let node: ExecutionPlanNode
        let rect: CGRect
        let children: [LayoutNode]
    }

    private struct LayoutItem {
        let node: ExecutionPlanNode
        let rect: CGRect
    }

    private struct ArrowInfo: Identifiable {
        let id: String
        let from: CGPoint   // child's left edge center (data source)
        let to: CGPoint     // parent's right edge center (data consumer)
        let rows: Double
        let costPercent: Double
    }

    /// Build a layout tree. Depth 0 = leftmost (root/result), increasing depth = rightward.
    private func buildLayout(_ node: ExecutionPlanNode, depth: Int, yOffset: CGFloat) -> LayoutNode {
        let x = CGFloat(depth) * (nodeWidth + hGap)

        if node.children.isEmpty {
            let rect = CGRect(x: x, y: yOffset, width: nodeWidth, height: nodeHeight)
            return LayoutNode(node: node, rect: rect, children: [])
        }

        var childLayouts: [LayoutNode] = []
        var currentY = yOffset
        for (i, child) in node.children.enumerated() {
            let childLayout = buildLayout(child, depth: depth + 1, yOffset: currentY)
            childLayouts.append(childLayout)
            currentY = subtreeMaxY(childLayout) + vGap
            if i < node.children.count - 1 {
                // Extra spacing between sibling branches
                currentY += vGap
            }
        }

        // Center parent vertically among its children
        let firstChildMidY = childLayouts.first!.rect.midY
        let lastChildMidY = childLayouts.last!.rect.midY
        let parentY = (firstChildMidY + lastChildMidY) / 2 - nodeHeight / 2

        let rect = CGRect(x: x, y: parentY, width: nodeWidth, height: nodeHeight)
        return LayoutNode(node: node, rect: rect, children: childLayouts)
    }

    private func subtreeMaxY(_ layout: LayoutNode) -> CGFloat {
        var maxY = layout.rect.maxY
        for child in layout.children {
            maxY = max(maxY, subtreeMaxY(child))
        }
        return maxY
    }

    private func treeWidth(_ layout: LayoutNode) -> CGFloat {
        var maxX = layout.rect.maxX
        for child in layout.children {
            maxX = max(maxX, treeWidth(child))
        }
        return maxX
    }

    private func treeHeight(_ layout: LayoutNode) -> CGFloat {
        var maxY = layout.rect.maxY
        for child in layout.children {
            maxY = max(maxY, treeHeight(child))
        }
        return maxY
    }

    // MARK: - Collect items for rendering

    private func collectLayoutNodes(_ layout: LayoutNode) -> [LayoutItem] {
        var result = [LayoutItem(node: layout.node, rect: layout.rect)]
        for child in layout.children {
            result.append(contentsOf: collectLayoutNodes(child))
        }
        return result
    }

    private func collectArrows(_ layout: LayoutNode) -> [ArrowInfo] {
        var result: [ArrowInfo] = []
        let parentRight = CGPoint(x: layout.rect.maxX, y: layout.rect.midY)

        for child in layout.children {
            let childLeft = CGPoint(x: child.rect.minX, y: child.rect.midY)
            let rows = child.node.estimateRows ?? 0
            let costPct: Double = {
                guard totalCost > 0, let opCost = child.node.operatorCost else { return 0 }
                return (opCost / totalCost) * 100
            }()

            result.append(ArrowInfo(
                id: "\(layout.node.id)-\(child.node.id)",
                from: childLeft,
                to: parentRight,
                rows: rows,
                costPercent: costPct
            ))
            result.append(contentsOf: collectArrows(child))
        }
        return result
    }

    // MARK: - Arrow styling

    private func arrowWidth(rows: Double) -> CGFloat {
        if rows <= 0 { return 1.5 }
        // Log scale for thickness: 1 row = 1.5pt, 1M rows = 6pt
        let logScale = log10(max(rows, 1)) / 6.0  // 6 = log10(1_000_000)
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

// MARK: - Arrow Shapes

/// A bezier curve arrow from source to destination.
private struct ArrowShape: Shape {
    let from: CGPoint
    let to: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: from)
        let controlOffset = abs(to.x - from.x) * 0.35
        path.addCurve(
            to: to,
            control1: CGPoint(x: from.x - controlOffset, y: from.y),
            control2: CGPoint(x: to.x + controlOffset, y: to.y)
        )
        return path
    }
}

/// A small triangular arrowhead pointing left.
private struct ArrowheadShape: Shape {
    let at: CGPoint
    let size: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Point faces left (toward parent)
        path.move(to: CGPoint(x: at.x + size, y: at.y - size * 0.5))
        path.addLine(to: at)
        path.addLine(to: CGPoint(x: at.x + size, y: at.y + size * 0.5))
        path.closeSubpath()
        return path
    }
}
