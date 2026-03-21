#if os(macOS)
import AppKit

final class ResultTableHeaderCell: NSTableHeaderCell {
    var columnSensitivity: ColumnSensitivity?

    override init(textCell: String) {
        super.init(textCell: textCell)
        lineBreakMode = .byTruncatingTail
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        lineBreakMode = .byTruncatingTail
    }

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        var adjusted = rect.insetBy(dx: ResultsGridMetrics.contentHorizontalPadding, dy: 0)
        if columnSensitivity != nil {
            adjusted.origin.x += ClassificationIndicatorMetrics.dotDiameter + ClassificationIndicatorMetrics.dotTrailingPadding
            adjusted.size.width -= ClassificationIndicatorMetrics.dotDiameter + ClassificationIndicatorMetrics.dotTrailingPadding
        }
        let attributed = attributedStringValue
        if attributed.length > 0 {
            let bounds = attributed.boundingRect(
                with: CGSize(width: adjusted.width, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
            let clampedHeight = min(bounds.height, adjusted.height)
            adjusted.origin.y = adjusted.midY - clampedHeight / 2
            adjusted.size.height = clampedHeight
        }
        adjusted.origin.y = floor(adjusted.origin.y)
        return adjusted
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        if let sensitivity = columnSensitivity {
            drawClassificationDot(sensitivity: sensitivity, in: cellFrame)
        }

        let baseAttributed: NSAttributedString
        if attributedStringValue.length > 0 {
            baseAttributed = attributedStringValue
        } else {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize),
                .foregroundColor: textColor ?? NSColor.labelColor
            ]
            baseAttributed = NSAttributedString(string: title, attributes: attributes)
        }
        let attributed = NSMutableAttributedString(attributedString: baseAttributed)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode = .byTruncatingTail
        attributed.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attributed.length))
        let options: NSString.DrawingOptions = [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
        let rect = titleRect(forBounds: cellFrame)
        attributed.draw(with: rect, options: options)
    }

    private func drawClassificationDot(sensitivity: ColumnSensitivity, in cellFrame: NSRect) {
        let color = ClassificationIndicatorMetrics.dotColor(for: sensitivity.effectiveRank)
        let diameter = ClassificationIndicatorMetrics.dotDiameter
        let x = cellFrame.minX + ResultsGridMetrics.contentHorizontalPadding
        let y = cellFrame.midY - diameter / 2
        let dotRect = NSRect(x: x, y: y, width: diameter, height: diameter)
        color.setFill()
        NSBezierPath(ovalIn: dotRect).fill()
    }
}

enum ClassificationIndicatorMetrics {
    static let dotDiameter: CGFloat = 6
    static let dotTrailingPadding: CGFloat = 4

    static func dotColor(for rank: SensitivityRank) -> NSColor {
        switch rank {
        case .notDefined: .systemGray
        case .low: .systemGreen
        case .medium: .systemYellow
        case .high: .systemOrange
        case .critical: .systemRed
        }
    }
}
#endif
