import SwiftUI

/// A simple flow layout that arranges its children in a horizontal flow,
/// wrapping to the next line when there's not enough space.
struct FlowLayout: Layout {
    var alignment: Alignment = .leading
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layoutSubviews(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = layoutSubviews(in: bounds.width, subviews: subviews)
        
        for (index, subview) in subviews.enumerated() {
            let point = layout.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private struct LayoutResult {
        var size: CGSize
        var positions: [CGPoint]
    }

    private func layoutSubviews(in maxWidth: CGFloat, subviews: Subviews) -> LayoutResult {
        var result = LayoutResult(size: .zero, positions: [])
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            result.positions.append(CGPoint(x: currentX, y: currentY))
            
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            result.size.width = max(result.size.width, currentX)
        }
        
        result.size.height = currentY + lineHeight
        return result
    }
}
