import AppKit
import SwiftUI

/// Round 28: where everything sits in a specimen, computed the way Echo computes it:
/// `SQLLayoutManager` for the line height, `LineNumberRulerView.thickness(forDigits:)` for the
/// gutter, `textContainerInset` (4pt) plus `lineFragmentPadding` (5pt) before the code.
@MainActor
struct LabQELayout {
    let style: LabQEStyle
    let codeFont: NSFont
    let numberFont: NSFont
    let advance: CGFloat
    let lineHeight: CGFloat
    let top: CGFloat
    /// The left edge of the line numbers' column (after the marker column, when there is one).
    let numbersLeft: CGFloat
    let numbersRight: CGFloat
    /// Where the gutter's surface ends and the text view begins.
    let gutterEdge: CGFloat
    let codeX: CGFloat

    /// Echo's text view starts this far before the first character (textContainerInset + lineFragmentPadding).
    static let textInset: CGFloat = 9

    init(style: LabQEStyle) {
        self.style = style
        let size = style.size.points * style.zoom.scale
        codeFont = LabQEFonts.nsFont(style.font, size: size, ligatures: style.ligatures == .on)
        let metrics = LabQEFonts.metrics(style.font, size: size)
        advance = metrics.advance
        lineHeight = style.lineHeight.height(size: size, natural: metrics.naturalLineHeight)
        top = style.topMargin.points * style.zoom.scale
        numberFont = switch style.numberFont {
        case .today: .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        case .smaller: .monospacedDigitSystemFont(ofSize: max(size - 2, 8), weight: .regular)
        case .codeFont: LabQEFonts.nsFont(style.font, size: max(size - 2, 8), ligatures: false)
        case .same: LabQEFonts.nsFont(style.font, size: size, ligatures: false)
        }
        let digitWidth = ("0" as NSString).size(withAttributes: [.font: numberFont]).width
        let digits = CGFloat(LayoutTokens.EditorGutter.minimumDigits)
        let markerColumn = LayoutTokens.EditorGutter.markerLeading + LayoutTokens.EditorGutter.markerSize + LayoutTokens.EditorGutter.markerSpacing
        numbersLeft = style.markers == .left ? markerColumn : SpacingTokens.xs
        numbersRight = ceil(numbersLeft + digitWidth * digits)
        let gap = style.codeGap.points + (style.markers == .between ? markerColumn : 0)
        codeX = numbersRight + gap
        gutterEdge = codeX - Self.textInset
    }

    func y(line: Int) -> CGFloat { top + CGFloat(line - 1) * lineHeight }
    func x(column: Int) -> CGFloat { codeX + CGFloat(column) * advance }

    /// The rectangle of a span; the whole line high, or as high as the letters.
    func rect(_ span: LabQESpan, lettersOnly: Bool = false) -> CGRect {
        let full = CGRect(x: x(column: span.start), y: y(line: span.line), width: CGFloat(span.end - span.start) * advance, height: lineHeight)
        guard lettersOnly else { return full }
        let letters = ceil(codeFont.ascender - codeFont.descender) + SpacingTokens.xxxs
        return full.insetBy(dx: -SpacingTokens.xxxs / 2, dy: max((lineHeight - letters) / 2, 0))
    }

    /// Where the markers (error dot, Run arrow) are drawn on a line.
    var markerX: CGFloat {
        switch style.markers {
        case .left: LayoutTokens.EditorGutter.markerLeading
        case .onNumber: numbersRight - LayoutTokens.EditorGutter.runArrowSize
        case .between: numbersRight + style.codeGap.points / 2
        }
    }
}
