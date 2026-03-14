#if os(macOS)
import AppKit

final class ResultTableHeaderCell: NSTableHeaderCell {
    override init(textCell: String) {
        super.init(textCell: textCell)
        lineBreakMode = .byTruncatingTail
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        lineBreakMode = .byTruncatingTail
    }

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        var adjusted = rect.insetBy(dx: ResultsGridMetrics.horizontalPadding, dy: 0)
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
}
#endif
