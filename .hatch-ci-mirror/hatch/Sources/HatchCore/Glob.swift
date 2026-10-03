import Foundation

/// Minimal path globs for area indexes and file claims: `*` within a segment, `**` across segments, `?` one character.
public enum Glob {
    public static func matches(_ pattern: String, _ path: String) -> Bool {
        match(Array(pattern.split(separator: "/", omittingEmptySubsequences: true).map(String.init)),
              Array(path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)))
    }

    private static func match(_ p: [String], _ s: [String]) -> Bool {
        if p.isEmpty { return s.isEmpty }
        if p[0] == "**" {
            if p.count == 1 { return true }
            for i in 0...s.count where match(Array(p.dropFirst()), Array(s.dropFirst(i))) { return true }
            return false
        }
        guard let first = s.first, segment(p[0], first) else { return false }
        return match(Array(p.dropFirst()), Array(s.dropFirst()))
    }

    private static func segment(_ pattern: String, _ text: String) -> Bool {
        let p = Array(pattern), t = Array(text)
        var memo: [[Bool?]] = Array(repeating: Array(repeating: nil, count: t.count + 1), count: p.count + 1)
        func go(_ i: Int, _ j: Int) -> Bool {
            if let m = memo[i][j] { return m }
            var r: Bool
            if i == p.count { r = j == t.count }
            else if p[i] == "*" { r = go(i + 1, j) || (j < t.count && go(i, j + 1)) }
            else if j < t.count && (p[i] == "?" || p[i] == t[j]) { r = go(i + 1, j + 1) }
            else { r = false }
            memo[i][j] = r
            return r
        }
        return go(0, 0)
    }

    /// True when two claims could touch the same file. Compares the fixed part before the first wildcard:
    /// if one is a prefix of the other, they overlap. Deliberately conservative, git decides at merge time.
    public static func mayOverlap(_ a: String, _ b: String) -> Bool {
        let pa = fixedPrefix(a), pb = fixedPrefix(b)
        if matches(a, b) || matches(b, a) { return true }
        let (short, long) = pa.count <= pb.count ? (pa, pb) : (pb, pa)
        return Array(long.prefix(short.count)) == short
    }

    private static func fixedPrefix(_ g: String) -> [String] {
        var out: [String] = []
        for seg in g.split(separator: "/") {
            if seg.contains("*") || seg.contains("?") { break }
            out.append(String(seg))
        }
        return out
    }
}
