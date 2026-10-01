#if os(macOS)
import AppKit

/// Rounds 28.13 (PV6) and 28.15: find matches and the replacement preview, in the marks' language.
/// A match is a soft yellow mark, the current one strong. While Replace is open, each match shows
/// what it would become: the old word struck through on a strong red mark, then the new word on a
/// soft green mark. NSTextView can't show text that isn't in the script, so the preview opens a
/// gap after each match with letter spacing and draws the new word into it; the script itself
/// never changes until Replace.
extension SQLTextView {
    private var previewSpace: NSString { " " }

    /// The gap a match's preview needs: a space and the replacement, in the editor's font.
    private var previewGap: CGFloat {
        ((previewSpace as String) + find.replacement as NSString).size(withAttributes: [.font: theme.nsFont]).width
    }

    func updateReplacePreview() {
        clearReplacePreview()
        guard find.isPreviewing, let textStorage, let layoutManager else { return }
        let gap = previewGap
        textStorage.beginEditing()
        for match in find.matches where match.length > 0 {
            textStorage.addAttribute(.kern, value: gap, range: NSRange(location: NSMaxRange(match) - 1, length: 1))
        }
        textStorage.endEditing()
        for match in find.matches {
            layoutManager.addTemporaryAttributes([
                .foregroundColor: NSColor.systemRed,
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .strikethroughColor: NSColor.systemRed,
            ], forCharacterRange: match)
        }
        hasReplacePreview = true
    }

    func clearReplacePreview() {
        guard hasReplacePreview, let textStorage, let layoutManager else { return }
        let all = NSRange(location: 0, length: textStorage.length)
        textStorage.beginEditing()
        textStorage.removeAttribute(.kern, range: all)
        textStorage.endEditing()
        for attribute in [NSAttributedString.Key.foregroundColor, .strikethroughStyle, .strikethroughColor] {
            layoutManager.removeTemporaryAttribute(attribute, forCharacterRange: all)
        }
        hasReplacePreview = false
    }

    /// Called from drawBackground.
    func drawFindMarks(in dirty: NSRect) {
        guard find.isOpen else { return }
        let current = find.currentMatch
        guard find.isPreviewing else {
            for match in find.matches { fillMarks(for: match, .found, match == current ? .strong : .soft, in: dirty) }
            return
        }
        let gap = previewGap
        let space = previewSpace.size(withAttributes: [.font: theme.nsFont]).width
        let font = theme.nsFont
        for match in find.matches {
            guard var removed = markRects(for: match).last else { continue }
            removed.size.width -= gap
            let strong: EditorMarkTokens.Strength = match == current ? .strong : .soft
            fill(removed, markColor(.wrong, .strong), in: dirty)
            let side = EditorMarkTokens.sidePadding
            let wordWidth = (find.replacement as NSString).size(withAttributes: [.font: font]).width
            let added = NSRect(x: removed.maxX - side + space - side, y: removed.minY, width: wordWidth + side * 2, height: removed.height)
            fill(added, markColor(.added, strong), in: dirty)
            // The mark's top is the letters' top less the padding, so the word sits on the line's baseline.
            (find.replacement as NSString).draw(at: NSPoint(x: added.minX + side, y: added.minY + EditorMarkTokens.verticalPadding),
                                                withAttributes: [.font: font, .foregroundColor: NSColor.systemGreen])
        }
    }

    private func fill(_ rect: NSRect, _ colour: NSColor, in dirty: NSRect) {
        guard rect.intersects(dirty) else { return }
        colour.setFill()
        let radius = displayOptions.markCorners.radius(forHeight: rect.height)
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
    }
}
#endif
