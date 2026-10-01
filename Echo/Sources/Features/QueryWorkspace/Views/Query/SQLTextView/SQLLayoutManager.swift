#if os(macOS)
import AppKit

/// Custom layout manager that enforces a fixed line height for every line,
/// including empty lines and the trailing extra line fragment.
/// This eliminates the inconsistent spacing that NSLayoutManager produces
/// when relying solely on NSParagraphStyle min/max line height.
final class SQLLayoutManager: NSLayoutManager, NSLayoutManagerDelegate {

    /// The editor font — stored separately to avoid fallback-font issues
    /// where `textView.font` returns the wrong font for the first character.
    var textFont: NSFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular) {
        didSet { recalculateLineMetrics() }
    }

    /// The line height as a multiple of the font size (round 28.1: 1.3, 1.55 or 1.75), never
    /// less than the font's own line height.
    var lineHeightMultiple: CGFloat = 1.55 {
        didSet { recalculateLineMetrics() }
    }

    /// Round 28.3: the selection's corner radius; 0 draws it square.
    var selectionCornerRadius: CGFloat = 0
    /// The text view's selection, handed over whenever it changes, so drawing can tell the
    /// selection's background from other background fills.
    var selectedRanges: [NSRange] = []

    /// The computed fixed line height used for every line fragment.
    private(set) var fixedLineHeight: CGFloat = 16
    /// The computed baseline offset within the fixed line height.
    private(set) var fixedBaselineOffset: CGFloat = 12

    override init() {
        super.init()
        delegate = self
        allowsNonContiguousLayout = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func recalculateLineMetrics() {
        let naturalHeight = defaultLineHeight(for: textFont)
        let naturalBaseline = defaultBaselineOffset(for: textFont)
        let targetHeight = Self.lineHeight(fontSize: textFont.pointSize, multiple: lineHeightMultiple, naturalHeight: naturalHeight)

        fixedLineHeight = targetHeight
        // Distribute extra space evenly above and below to center glyphs vertically.
        let extraSpace = targetHeight - naturalHeight
        fixedBaselineOffset = naturalBaseline + extraSpace * 0.5
    }

    /// A line `multiple` times the font size, rounded to whole points, so glyphs never clip.
    static func lineHeight(fontSize: CGFloat, multiple: CGFloat, naturalHeight: CGFloat) -> CGFloat {
        max((fontSize * multiple).rounded(), ceil(naturalHeight))
    }

    // MARK: - Rounded selection

    /// Round 28.3: the selection is drawn with rounded corners. Other background fills (the
    /// highlighted uses of a word) stay as they are.
    override func fillBackgroundRectArray(_ rectArray: UnsafePointer<NSRect>, count rectCount: Int,
                                          forCharacterRange charRange: NSRange, color: NSColor) {
        guard selectionCornerRadius > 0, isSelected(charRange) else {
            super.fillBackgroundRectArray(rectArray, count: rectCount, forCharacterRange: charRange, color: color)
            return
        }
        for index in 0..<rectCount {
            let rect = rectArray[index]
            let radius = min(selectionCornerRadius, rect.height / 2, rect.width / 2)
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
        }
    }

    private func isSelected(_ range: NSRange) -> Bool {
        selectedRanges.contains { NSIntersectionRange($0, range).length > 0 }
    }

    // MARK: - Extra Line Fragment Override

    override func setExtraLineFragmentRect(
        _ fragmentRect: NSRect,
        usedRect: NSRect,
        textContainer container: NSTextContainer
    ) {
        var rect = fragmentRect
        var used = usedRect
        rect.size.height = fixedLineHeight
        used.size.height = fixedLineHeight
        super.setExtraLineFragmentRect(rect, usedRect: used, textContainer: container)
    }

    // MARK: - NSLayoutManagerDelegate

    func layoutManager(
        _ layoutManager: NSLayoutManager,
        shouldSetLineFragmentRect lineFragmentRect: UnsafeMutablePointer<NSRect>,
        lineFragmentUsedRect: UnsafeMutablePointer<NSRect>,
        baselineOffset: UnsafeMutablePointer<CGFloat>,
        in textContainer: NSTextContainer,
        forGlyphRange glyphRange: NSRange
    ) -> Bool {
        lineFragmentRect.pointee.size.height = fixedLineHeight
        lineFragmentUsedRect.pointee.size.height = fixedLineHeight
        baselineOffset.pointee = fixedBaselineOffset
        return true
    }
}
#endif
