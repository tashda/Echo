#if os(macOS)
import AppKit

final class ResultTableRowView: NSTableRowView {
    private var rowIndex: Int = 0
    private var colorProvider: ((Int) -> NSColor)?

    struct SelectionRenderInfo {
        let rect: NSRect
        let topCornerRadius: CGFloat
        let bottomCornerRadius: CGFloat
    }

    private var highlightProvider: ((ResultTableRowView, Int) -> SelectionRenderInfo?)?

    func configure(row: Int,
                   colorProvider: @escaping (Int) -> NSColor,
                   highlightProvider: @escaping (ResultTableRowView, Int) -> SelectionRenderInfo?) {
        self.rowIndex = row
        self.colorProvider = colorProvider
        self.highlightProvider = highlightProvider
        needsDisplay = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        colorProvider = nil
        highlightProvider = nil
    }

    override func drawBackground(in dirtyRect: NSRect) {
        let color = colorProvider?(rowIndex) ?? NSColor.clear
        color.setFill()
        dirtyRect.fill()

        if let info = highlightProvider?(self, rowIndex) {
            let accent = ThemeManager.shared.accentNSColor
            let fill = accent.withAlphaComponent(0.18)
            let stroke = accent.withAlphaComponent(0.65)
            let path = makeRoundedPath(in: info.rect, topRadius: info.topCornerRadius, bottomRadius: info.bottomCornerRadius)
            fill.setFill()
            path.fill()
            stroke.setStroke()
            path.lineWidth = 1
            path.stroke()
        }
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
