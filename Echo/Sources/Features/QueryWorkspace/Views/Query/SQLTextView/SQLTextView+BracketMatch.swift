#if os(macOS)
import AppKit

/// Round 28.5 (P1): typing a closing bracket flashes its partner with the system's find
/// indicator, as NSTextView and Xcode do; nothing stays marked.
extension SQLTextView {
    func flashMatchingBracket(closingAt index: Int) {
        guard let partner = Self.matchingOpenBracket(in: string as NSString, closingAt: index) else { return }
        showFindIndicator(for: NSRange(location: partner, length: 1))
    }

    /// The `(` that the `)` at `index` closes, skipping brackets inside quotes and `--` comments
    /// on the way back; nil when there is none.
    static func matchingOpenBracket(in text: NSString, closingAt index: Int) -> Int? {
        guard index < text.length, text.character(at: index) == UInt16(UInt8(ascii: ")")) else { return nil }
        let open = UInt16(UInt8(ascii: "(")), close = UInt16(UInt8(ascii: ")"))
        let single = UInt16(UInt8(ascii: "'")), double = UInt16(UInt8(ascii: "\""))
        var depth = 0
        var quote: UInt16?
        var position = index - 1
        while position >= 0 {
            let character = text.character(at: position)
            if let open = quote {
                if character == open { quote = nil }
            } else if character == single || character == double {
                quote = character
            } else if character == close {
                depth += 1
            } else if character == open {
                if depth == 0 { return isInLineComment(text, at: position) ? nil : position }
                depth -= 1
            }
            position -= 1
        }
        return nil
    }

    private static func isInLineComment(_ text: NSString, at index: Int) -> Bool {
        let line = text.lineRange(for: NSRange(location: index, length: 0))
        let before = text.substring(with: NSRange(location: line.location, length: index - line.location))
        return before.contains("--")
    }
}
#endif
