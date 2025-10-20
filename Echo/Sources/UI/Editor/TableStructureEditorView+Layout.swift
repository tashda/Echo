import SwiftUI
import Foundation
#if os(macOS)
import AppKit
#endif

// MARK: - Layout Helpers

struct FlowLayout: Layout {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }

        let availableWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let itemWidth = size.width

            if rowWidth > 0, rowWidth + spacing + itemWidth > availableWidth {
                totalHeight += rowHeight + spacing
                maxRowWidth = max(maxRowWidth, rowWidth)
                rowWidth = 0
                rowHeight = 0
            }

            rowWidth += itemWidth
            rowHeight = max(rowHeight, size.height)
            if subview != subviews.last {
                rowWidth += spacing
            }
        }

        totalHeight += rowHeight
        maxRowWidth = max(maxRowWidth, rowWidth)

        return CGSize(width: min(maxRowWidth, availableWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }

        var origin = bounds.origin
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let itemWidth = size.width

            if origin.x > bounds.origin.x, origin.x + itemWidth > bounds.maxX {
                origin.x = bounds.origin.x
                origin.y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(at: CGPoint(x: origin.x, y: origin.y), proposal: ProposedViewSize(width: size.width, height: size.height))

            origin.x += itemWidth + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#if os(macOS)
extension Color {
    var nsColor: NSColor? {
        if let cgColor = self.cgColor {
            return NSColor(cgColor: cgColor)
        }
        return NSColor(self)
    }
}
#endif
