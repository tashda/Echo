import Foundation

/// Finds the statement the caret is in, for Run Statement at Cursor (plan K1).
///
/// A statement ends at a semicolon, a blank line, or a line holding only `GO`, like DBeaver's
/// "blank line is a delimiter". Quotes (`'…'`, `"…"`, `` `…` ``, `[…]`, `$tag$…$tag$`) and comments
/// never end one. A caret on a blank line or after the last semicolon picks the statement before it.
nonisolated enum SQLStatementAtCaret {
    struct Match: Equatable, Sendable {
        let text: String
        /// UTF-16 range of `text` in the script, for selecting it in the editor.
        let range: NSRange
    }

    static func statement(in sql: String, caret: Int) -> Match? {
        let units = Array(sql.utf16)
        let segments = split(units)
        let caret = min(max(caret, 0), units.count)
        let trimmed: [Match] = segments.compactMap { trim($0, in: units) }
        guard !trimmed.isEmpty else { return nil }
        if let inside = trimmed.first(where: { caret >= $0.range.location && caret <= NSMaxRange($0.range) }) {
            return inside
        }
        return trimmed.last(where: { NSMaxRange($0.range) <= caret }) ?? trimmed.first
    }

    // MARK: - Splitting

    private static func split(_ units: [UInt16]) -> [Range<Int>] {
        var segments: [Range<Int>] = []
        var start = 0
        var index = 0
        while index < units.count {
            let unit = units[index]
            if let end = skippedQuoteOrComment(units, at: index) {
                index = end
                continue
            }
            if unit == semicolon {
                segments.append(start..<(index + 1))
                start = index + 1
            } else if unit == newline, let next = blankLineEnd(units, after: index) {
                segments.append(start..<index)
                start = next
                index = next
                continue
            } else if isLineStart(units, index), let end = goLineEnd(units, at: index) {
                segments.append(start..<index)
                start = end
                index = end
                continue
            }
            index += 1
        }
        if start < units.count { segments.append(start..<units.count) }
        return segments
    }

    /// The end of a quote or comment starting at `index`, or nil when none starts there.
    private static func skippedQuoteOrComment(_ units: [UInt16], at index: Int) -> Int? {
        let unit = units[index]
        let next = index + 1 < units.count ? units[index + 1] : 0
        switch unit {
        case singleQuote, doubleQuote, backtick:
            return closing(unit, in: units, from: index + 1)
        case openBracket:
            return closing(closeBracket, in: units, from: index + 1)
        case dash where next == dash:
            var end = index
            while end < units.count, units[end] != newline { end += 1 }
            return end
        case slash where next == star:
            var end = index + 2
            while end + 1 < units.count, !(units[end] == star && units[end + 1] == slash) { end += 1 }
            return min(end + 2, units.count)
        case dollar:
            return dollarQuoteEnd(units, at: index)
        default:
            return nil
        }
    }

    private static func closing(_ quote: UInt16, in units: [UInt16], from start: Int) -> Int {
        var end = start
        while end < units.count {
            if units[end] == quote {
                // A doubled quote is an escaped one.
                if end + 1 < units.count, units[end + 1] == quote { end += 2; continue }
                return end + 1
            }
            end += 1
        }
        return units.count
    }

    private static func dollarQuoteEnd(_ units: [UInt16], at index: Int) -> Int? {
        var tagEnd = index + 1
        while tagEnd < units.count, isTagUnit(units[tagEnd]) { tagEnd += 1 }
        guard tagEnd < units.count, units[tagEnd] == dollar else { return nil }
        let tag = Array(units[index...tagEnd])
        var search = tagEnd + 1
        while search + tag.count <= units.count {
            if Array(units[search..<(search + tag.count)]) == tag { return search + tag.count }
            search += 1
        }
        return units.count
    }

    /// Where the next line starts when the line after `newlineIndex` is blank; nil otherwise.
    private static func blankLineEnd(_ units: [UInt16], after newlineIndex: Int) -> Int? {
        var index = newlineIndex + 1
        while index < units.count, units[index] == space || units[index] == tab || units[index] == carriageReturn {
            index += 1
        }
        guard index < units.count, units[index] == newline else { return nil }
        return index + 1
    }

    private static func goLineEnd(_ units: [UInt16], at index: Int) -> Int? {
        var cursor = index
        while cursor < units.count, units[cursor] == space || units[cursor] == tab { cursor += 1 }
        guard cursor + 1 < units.count,
              units[cursor] | 0x20 == 0x67, units[cursor + 1] | 0x20 == 0x6F else { return nil }
        cursor += 2
        while cursor < units.count, units[cursor] == space || units[cursor] == tab || units[cursor] == carriageReturn { cursor += 1 }
        guard cursor == units.count || units[cursor] == newline else { return nil }
        return cursor
    }

    private static func isLineStart(_ units: [UInt16], _ index: Int) -> Bool {
        index == 0 || units[index - 1] == newline
    }

    private static func isTagUnit(_ unit: UInt16) -> Bool {
        (0x30...0x39).contains(unit) || (0x41...0x5A).contains(unit) || (0x61...0x7A).contains(unit) || unit == 0x5F
    }

    private static func trim(_ segment: Range<Int>, in units: [UInt16]) -> Match? {
        var lower = segment.lowerBound
        var upper = segment.upperBound
        while lower < upper, isWhitespace(units[lower]) { lower += 1 }
        while upper > lower, isWhitespace(units[upper - 1]) || units[upper - 1] == semicolon { upper -= 1 }
        guard lower < upper else { return nil }
        let text = String(decoding: units[lower..<upper], as: UTF16.self)
        return Match(text: text, range: NSRange(location: lower, length: upper - lower))
    }

    private static func isWhitespace(_ unit: UInt16) -> Bool {
        unit == space || unit == tab || unit == newline || unit == carriageReturn
    }

    private static let semicolon: UInt16 = 0x3B
    private static let newline: UInt16 = 0x0A
    private static let carriageReturn: UInt16 = 0x0D
    private static let space: UInt16 = 0x20
    private static let tab: UInt16 = 0x09
    private static let singleQuote: UInt16 = 0x27
    private static let doubleQuote: UInt16 = 0x22
    private static let backtick: UInt16 = 0x60
    private static let openBracket: UInt16 = 0x5B
    private static let closeBracket: UInt16 = 0x5D
    private static let dash: UInt16 = 0x2D
    private static let slash: UInt16 = 0x2F
    private static let star: UInt16 = 0x2A
    private static let dollar: UInt16 = 0x24
}
