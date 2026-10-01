#if os(macOS)
import AppKit
import SwiftUI

final class ResultTableRowView: NSTableRowView {
    private var rowIndex: Int = 0
    private var colorProvider: ((Int) -> NSColor)?

    struct SelectionRenderInfo {
        let rect: NSRect
        /// Corner radius on the maxY side; nonzero only where the range's outline closes.
        let topCornerRadius: CGFloat
        /// Corner radius on the minY side; nonzero only where the range's outline closes.
        let bottomCornerRadius: CGFloat
        /// The active cell, which gets a stronger ring, when it's in this row.
        var activeCellRect: NSRect? = nil
    }

    /// The pointer is over this row (plan R4): a faint rounded tint.
    var isHovered = false {
        didSet { if oldValue != isHovered { needsDisplay = true } }
    }

    private var highlightProvider: ((ResultTableRowView, Int) -> [SelectionRenderInfo])?

    func configure(row: Int,
                   colorProvider: @escaping (Int) -> NSColor,
                   highlightProvider: @escaping (ResultTableRowView, Int) -> [SelectionRenderInfo]) {
        self.rowIndex = row
        self.colorProvider = colorProvider
        self.highlightProvider = highlightProvider
        needsDisplay = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        colorProvider = nil
        highlightProvider = nil
        isHovered = false
    }

    override func drawBackground(in dirtyRect: NSRect) {
        if let tableView = superview as? NSTableView, tableView.usesAlternatingRowBackgroundColors {
            super.drawBackground(in: dirtyRect)
        } else {
            let color = colorProvider?(rowIndex) ?? NSColor.clear
            color.setFill()
            dirtyRect.fill()
        }

        if isHovered {
            let hover = bounds.insetBy(dx: ResultsGridMetrics.hoverHorizontalInset, dy: ResultsGridMetrics.hoverVerticalInset)
            NSColor(ColorTokens.Sidebar.hoverFill).setFill()
            NSBezierPath(roundedRect: hover, xRadius: ResultsGridMetrics.hoverCornerRadius, yRadius: ResultsGridMetrics.hoverCornerRadius).fill()
        }

        if let infos = highlightProvider?(self, rowIndex) {
            let accent = AppearanceStore.shared.accentNSColor
            let fill = accent.withAlphaComponent(0.18)
            let stroke = accent.withAlphaComponent(0.65)
            for info in infos {
                fill.setFill()
                makeRoundedPath(in: info.rect, topRadius: info.topCornerRadius, bottomRadius: info.bottomCornerRadius).fill()
                // One outline around the whole range (plan R3): each row strokes its sides, and
                // only the rows where the range starts or ends close it, so rows show no seams.
                stroke.setStroke()
                let outline = makeOutlinePath(in: info.rect, topRadius: info.topCornerRadius, bottomRadius: info.bottomCornerRadius)
                outline.lineWidth = 1
                outline.stroke()
                if let cell = info.activeCellRect {
                    accent.setStroke()
                    let ring = NSBezierPath(
                        roundedRect: cell.insetBy(dx: ResultsGridMetrics.activeCellRingWidth / 2, dy: ResultsGridMetrics.activeCellRingWidth / 2),
                        xRadius: ResultsGridMetrics.activeCellCornerRadius,
                        yRadius: ResultsGridMetrics.activeCellCornerRadius
                    )
                    ring.lineWidth = ResultsGridMetrics.activeCellRingWidth
                    ring.stroke()
                }
            }
        }
    }

    /// The outline for one row of a selected range: both sides always, and the maxY or minY edge
    /// (with its corners) only where the range starts or ends.
    private func makeOutlinePath(in rect: NSRect, topRadius: CGFloat, bottomRadius: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        let topR = min(topRadius, rect.width / 2, rect.height / 2)
        let bottomR = min(bottomRadius, rect.width / 2, rect.height / 2)
        let closesTop = topRadius > 0
        let closesBottom = bottomRadius > 0

        // Left side, bottom to top.
        path.move(to: NSPoint(x: rect.minX, y: rect.minY + bottomR))
        path.line(to: NSPoint(x: rect.minX, y: rect.maxY - topR))
        if closesTop {
            path.appendArc(withCenter: NSPoint(x: rect.minX + topR, y: rect.maxY - topR), radius: topR, startAngle: 180, endAngle: 90, clockwise: true)
            path.line(to: NSPoint(x: rect.maxX - topR, y: rect.maxY))
            path.appendArc(withCenter: NSPoint(x: rect.maxX - topR, y: rect.maxY - topR), radius: topR, startAngle: 90, endAngle: 0, clockwise: true)
        } else {
            path.move(to: NSPoint(x: rect.maxX, y: rect.maxY))
        }
        // Right side, top to bottom.
        path.line(to: NSPoint(x: rect.maxX, y: rect.minY + bottomR))
        if closesBottom {
            path.appendArc(withCenter: NSPoint(x: rect.maxX - bottomR, y: rect.minY + bottomR), radius: bottomR, startAngle: 0, endAngle: 270, clockwise: true)
            path.line(to: NSPoint(x: rect.minX + bottomR, y: rect.minY))
            path.appendArc(withCenter: NSPoint(x: rect.minX + bottomR, y: rect.minY + bottomR), radius: bottomR, startAngle: 270, endAngle: 180, clockwise: true)
        }
        return path
    }

    override func drawSelection(in dirtyRect: NSRect) {}

    override var isEmphasized: Bool {
        get { false }
        set { }
    }

    private func makeRoundedPath(in rect: NSRect, topRadius: CGFloat, bottomRadius: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        let topR = min(topRadius, rect.width / 2, rect.height / 2)
        let bottomR = min(bottomRadius, rect.width / 2, rect.height / 2)

        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY

        path.move(to: NSPoint(x: minX, y: minY + bottomR))

        if bottomR > 0 {
            path.appendArc(withCenter: NSPoint(x: minX + bottomR, y: minY + bottomR), radius: bottomR, startAngle: 180, endAngle: 270)
        } else {
            path.line(to: NSPoint(x: minX, y: minY))
        }

        path.line(to: NSPoint(x: maxX - bottomR, y: minY))

        if bottomR > 0 {
            path.appendArc(withCenter: NSPoint(x: maxX - bottomR, y: minY + bottomR), radius: bottomR, startAngle: 270, endAngle: 360)
        } else {
            path.line(to: NSPoint(x: maxX, y: minY))
        }

        path.line(to: NSPoint(x: maxX, y: maxY - topR))

        if topR > 0 {
            path.appendArc(withCenter: NSPoint(x: maxX - topR, y: maxY - topR), radius: topR, startAngle: 0, endAngle: 90)
        } else {
            path.line(to: NSPoint(x: maxX, y: maxY))
        }

        path.line(to: NSPoint(x: minX + topR, y: maxY))

        if topR > 0 {
            path.appendArc(withCenter: NSPoint(x: minX + topR, y: maxY - topR), radius: topR, startAngle: 90, endAngle: 180)
        } else {
            path.line(to: NSPoint(x: minX, y: maxY))
        }

        path.close()
        return path
    }
}
#endif
