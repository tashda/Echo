import Foundation

/// Ranks palette rows against what was typed. Higher is better; nil means no match.
/// A prefix beats a word start, a word start beats a substring, and a substring beats letters in
/// order (so "nqi" finds "New Query in …").
nonisolated enum CommandPaletteMatcher {
    static func score(_ query: String, title: String, keywords: String = "") -> Int? {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return 0 }
        let haystack = title.lowercased()
        if haystack.hasPrefix(needle) { return 1_000 - min(haystack.count, 500) }
        if let range = haystack.range(of: needle) {
            let startsWord = range.lowerBound == haystack.startIndex
                || !haystack[haystack.index(before: range.lowerBound)].isLetter
            return (startsWord ? 800 : 600) - min(haystack.count, 500)
        }
        if !keywords.isEmpty, keywords.lowercased().contains(needle) { return 400 }
        return subsequenceScore(needle, in: haystack)
    }

    private static func subsequenceScore(_ needle: String, in haystack: String) -> Int? {
        var score = 0
        var run = 0
        var remaining = needle[...]
        for character in haystack {
            guard let next = remaining.first else { break }
            if character == next {
                run += 1
                score += run * 2
                remaining = remaining.dropFirst()
            } else {
                run = 0
            }
        }
        return remaining.isEmpty ? min(score, 300) : nil
    }
}
