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

    /// Extra spacing added between lines (on top of the font's natural line height).
    var extraLineSpacing: CGFloat = 0 {
        didSet { recalculateLineMetrics() }
    }

    /// Multiplier applied to the font's natural line height.
    var lineHeightMultiple: CGFloat = 1.0 {
        didSet { recalculateLineMetrics() }
    }

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
        let targetHeight = ceil(naturalHeight * lineHeightMultiple + extraLineSpacing)

        fixedLineHeight = targetHeight
        // Distribute extra space evenly above and below to center glyphs vertically.
        let extraSpace = targetHeight - naturalHeight
        fixedBaselineOffset = naturalBaseline + extraSpace * 0.5
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
