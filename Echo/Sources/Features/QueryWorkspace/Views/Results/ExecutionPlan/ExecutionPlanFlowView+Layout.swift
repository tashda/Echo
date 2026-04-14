import SwiftUI

extension ExecutionPlanFlowView {

    struct LayoutNode {
        let node: ExecutionPlanNode
        let rect: CGRect
        let children: [LayoutNode]
    }

    struct LayoutItem {
        let node: ExecutionPlanNode
        let rect: CGRect
    }

    struct ArrowInfo: Identifiable {
        let id: String
        let from: CGPoint   // child's left edge center (data source)
        let to: CGPoint     // parent's right edge center (data consumer)
        let rows: Double
        let costPercent: Double
    }

    /// Build a layout tree. Depth 0 = leftmost (root/result), increasing depth = rightward.
    func buildLayout(_ node: ExecutionPlanNode, depth: Int, yOffset: CGFloat) -> LayoutNode {
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
                currentY += vGap
            }
        }

        let firstChildMidY = childLayouts.first!.rect.midY
        let lastChildMidY = childLayouts.last!.rect.midY
        let parentY = (firstChildMidY + lastChildMidY) / 2 - nodeHeight / 2

        let rect = CGRect(x: x, y: parentY, width: nodeWidth, height: nodeHeight)
        return LayoutNode(node: node, rect: rect, children: childLayouts)
    }

    func subtreeMaxY(_ layout: LayoutNode) -> CGFloat {
        var maxY = layout.rect.maxY
        for child in layout.children {
            maxY = max(maxY, subtreeMaxY(child))
        }
        return maxY
    }

    func treeWidth(_ layout: LayoutNode) -> CGFloat {
        var maxX = layout.rect.maxX
        for child in layout.children {
            maxX = max(maxX, treeWidth(child))
        }
        return maxX
    }

    func treeHeight(_ layout: LayoutNode) -> CGFloat {
        var maxY = layout.rect.maxY
        for child in layout.children {
            maxY = max(maxY, treeHeight(child))
        }
        return maxY
    }

    func collectLayoutNodes(_ layout: LayoutNode) -> [LayoutItem] {
        var result = [LayoutItem(node: layout.node, rect: layout.rect)]
        for child in layout.children {
            result.append(contentsOf: collectLayoutNodes(child))
        }
        return result
    }

    func collectArrows(_ layout: LayoutNode) -> [ArrowInfo] {
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
}
