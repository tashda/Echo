#if os(macOS)
import AppKit

/// A results column header (Design/05-components.md › Results card, plan R2): the column name in
/// 12pt semibold with its data type underneath in grey monospace, and a sort arrow at the
/// trailing edge that shows while sorted or hovered. The header view turns a click on the arrow
/// into a sort and a click anywhere else into a column selection.
final class ResultTableHeaderCell: NSTableHeaderCell {
    enum SortState { case none, ascending, descending }

    var columnSensitivity: ColumnSensitivity?
    /// The column's data type, shown under its name.
    var typeName: String?
    var sortState: SortState = .none
    var isHovered = false
    /// Always Encrypted (round 29, EH1): a lock after the name.
    var isEncrypted = false

    static let nameFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
    static let typeFont = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)

    override init(textCell: String) {
        super.init(textCell: textCell)
        lineBreakMode = .byTruncatingTail
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        lineBreakMode = .byTruncatingTail
    }

    /// `NSCell` copies itself byte by byte, so a copy's Swift properties would point at this
    /// cell's values without owning them, and freeing the copy over-released them. AppKit copies
    /// the last header cell to draw the empty header past the last column, which crashed while
    /// results streamed in (EXC_BREAKPOINT in `drawInterior`, 2026-10-01). The copy takes
    /// ownership here: `initialize` writes without releasing the byte-copied value.
    override func copy(with zone: NSZone? = nil) -> Any {
        let copy = super.copy(with: zone)
        guard let cell = copy as? ResultTableHeaderCell else { return copy }
        withUnsafeMutablePointer(to: &cell.typeName) { $0.initialize(to: typeName) }
        withUnsafeMutablePointer(to: &cell.columnSensitivity) { $0.initialize(to: columnSensitivity) }
        return cell
    }

    /// Where the sort arrow sits inside a header cell's frame.
    static func sortIndicatorRect(in cellFrame: NSRect) -> NSRect {
        let size = ResultsGridMetrics.sortIndicatorSize
        return NSRect(
            x: cellFrame.maxX - ResultsGridMetrics.contentHorizontalPadding - size,
            y: cellFrame.midY - size / 2,
            width: size,
            height: size
        )
    }

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        var adjusted = rect.insetBy(dx: ResultsGridMetrics.contentHorizontalPadding, dy: 0)
        if columnSensitivity != nil {
            adjusted.origin.x += ClassificationIndicatorMetrics.dotDiameter + ClassificationIndicatorMetrics.dotTrailingPadding
            adjusted.size.width -= ClassificationIndicatorMetrics.dotDiameter + ClassificationIndicatorMetrics.dotTrailingPadding
        }
        // Room for the sort arrow, so names never run under it.
        adjusted.size.width -= ResultsGridMetrics.sortIndicatorSize + SpacingTokens.xxs
        return adjusted
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        if let sensitivity = columnSensitivity {
            drawClassificationDot(sensitivity: sensitivity, in: cellFrame)
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineBreakMode = .byTruncatingTail
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: Self.nameFont,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
        let name = NSMutableAttributedString(string: title, attributes: nameAttributes)
        if isEncrypted, let lock = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Always Encrypted")?
            .withSymbolConfiguration(.init(pointSize: Self.nameFont.pointSize * 0.8, weight: .regular)) {
            let attachment = NSTextAttachment()
            attachment.image = lock
            let symbol = NSMutableAttributedString(attachment: attachment)
            symbol.addAttributes([.foregroundColor: NSColor.tertiaryLabelColor], range: NSRange(location: 0, length: symbol.length))
            name.append(NSAttributedString(string: " ", attributes: nameAttributes))
            name.append(symbol)
        }
        let type = typeName.flatMap { $0.isEmpty ? nil : $0 }.map {
            NSAttributedString(string: $0, attributes: [
                .font: Self.typeFont,
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraph
            ])
        }

        let textRect = titleRect(forBounds: cellFrame)
        let nameHeight = ceil(Self.nameFont.ascender - Self.nameFont.descender)
        let typeHeight = type == nil ? 0 : ceil(Self.typeFont.ascender - Self.typeFont.descender)
        let blockHeight = nameHeight + typeHeight
        // Header views are flipped: y grows downward.
        let top = floor(cellFrame.midY - blockHeight / 2)
        let options: NSString.DrawingOptions = [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
        name.draw(with: NSRect(x: textRect.minX, y: top, width: textRect.width, height: nameHeight), options: options)
        type?.draw(with: NSRect(x: textRect.minX, y: top + nameHeight, width: textRect.width, height: typeHeight), options: options)

        drawSortIndicator(in: cellFrame)
    }

    private func drawSortIndicator(in cellFrame: NSRect) {
        let symbolName: String
        let color: NSColor
        switch sortState {
        case .ascending:
            symbolName = "chevron.up"
            color = .controlAccentColor
        case .descending:
            symbolName = "chevron.down"
            color = .controlAccentColor
        case .none:
            guard isHovered else { return }
            symbolName = "chevron.up.chevron.down"
            color = .tertiaryLabelColor
        }
        let configuration = NSImage.SymbolConfiguration(pointSize: ResultsGridMetrics.sortIndicatorPointSize, weight: .semibold)
            .applying(.init(paletteColors: [color]))
        guard let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else { return }
        let box = Self.sortIndicatorRect(in: cellFrame)
        let size = image.size
        let origin = NSPoint(x: box.midX - size.width / 2, y: box.midY - size.height / 2)
        image.draw(in: NSRect(origin: origin, size: size), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
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
