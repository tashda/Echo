import Foundation
import Observation

/// Rounds 28.12 and 28.13: the editor's own find and replace (FB5), replacing the system's find
/// bar. One per text view; the bar shows it and the text view draws its matches.
@MainActor @Observable
final class EditorFind {
    var isOpen = false
    /// RP1: Replace opens inside the capsule with the chevron (AN1: it grows).
    var isReplaceOpen = false
    var query = "" { didSet { if query != oldValue { status = nil; onChange?() } } }
    var replacement = "" { didSet { if replacement != oldValue { onChange?() } } }
    /// O0: the magnifier's menu.
    var matchCase = false { didSet { onChange?() } }
    var wholeWords = false { didSet { onChange?() } }
    var matches: [NSRange] = []
    var current = 0
    /// RA0: “Replaced 12” until you type again.
    var status: String?
    /// SS4: the multi-line selection find started from; the Selection button limits the search to it.
    var scope: NSRange?
    var isScopeOn = false { didSet { onChange?() } }
    /// Bumped to put the caret in the Find field.
    var focusRequest = 0

    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored var onNext: (() -> Void)?
    @ObservationIgnored var onPrevious: (() -> Void)?
    @ObservationIgnored var onReplace: (() -> Void)?
    @ObservationIgnored var onReplaceAll: (() -> Void)?
    @ObservationIgnored var onClose: (() -> Void)?

    /// C0: “2 found”.
    var countText: String { status ?? "\(matches.count) found" }

    /// PV6 is showing: Replace is open and there is something to replace with.
    var isPreviewing: Bool { isOpen && isReplaceOpen && !replacement.isEmpty && !matches.isEmpty }

    var currentMatch: NSRange? { matches.indices.contains(current) ? matches[current] : nil }

    /// Every match of `query` in `text` (RX0: no regular expressions), inside `scope` when given.
    nonisolated static func matches(of query: String, in text: NSString, scope: NSRange? = nil,
                                    matchCase: Bool = false, wholeWords: Bool = false) -> [NSRange] {
        guard !query.isEmpty, text.length > 0 else { return [] }
        let options: NSString.CompareOptions = matchCase ? [] : [.caseInsensitive]
        let limit = scope.map { NSIntersectionRange($0, NSRange(location: 0, length: text.length)) } ?? NSRange(location: 0, length: text.length)
        var results: [NSRange] = []
        var search = limit
        while search.length > 0 {
            let found = text.range(of: query, options: options, range: search)
            guard found.location != NSNotFound else { break }
            if !wholeWords || isWholeWord(found, in: text) { results.append(found) }
            let next = NSMaxRange(found)
            search = NSRange(location: next, length: NSMaxRange(limit) - next)
        }
        return results
    }

    nonisolated private static func isWholeWord(_ range: NSRange, in text: NSString) -> Bool {
        func isWordCharacter(_ index: Int) -> Bool {
            guard index >= 0, index < text.length, let scalar = UnicodeScalar(text.character(at: index)) else { return false }
            return CharacterSet.alphanumerics.contains(scalar) || scalar == "_"
        }
        return !isWordCharacter(range.location - 1) && !isWordCharacter(NSMaxRange(range))
    }
}
