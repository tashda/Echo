import Foundation

/// A tiny, forgiving reader for Swift source text. Echo Labs keeps round info and spec elements as Swift initialisers, and
/// we only need their string arguments, so this scans for balanced parentheses and string literals instead of parsing Swift.
/// Every function returns nil or skips on odd input rather than crashing.
enum SwiftSource {
    /// Reads a string literal starting at the opening quote. Returns the decoded text and the index after the closing quote.
    static func readString(_ s: [Character], at start: Int) -> (text: String, end: Int)? {
        guard start < s.count, s[start] == "\"" else { return nil }
        let multiline = start + 2 < s.count && s[start + 1] == "\"" && s[start + 2] == "\""
        var i = start + (multiline ? 3 : 1)
        var out = ""
        while i < s.count {
            let c = s[i]
            if multiline {
                if c == "\"", i + 2 < s.count, s[i + 1] == "\"", s[i + 2] == "\"" { return (out, i + 3) }
            } else {
                if c == "\"" { return (out, i + 1) }
                if c == "\n" { return nil }   // an unterminated single-line string: give up on this one
            }
            if c == "\\" {
                guard i + 1 < s.count else { return nil }
                let n = s[i + 1]
                switch n {
                case "n": out.append("\n"); i += 2
                case "t": out.append("\t"); i += 2
                case "r": out.append("\r"); i += 2
                case "0": out.append("\0"); i += 2
                case "(":
                    // Interpolation: skip to the matching paren; keep a visible placeholder.
                    if let close = closingParen(s, openAt: i + 1) { out.append("…"); i = close + 1 } else { return nil }
                case "u":
                    if i + 2 < s.count, s[i + 2] == "{", let close = s[(i + 3)...].firstIndex(of: "}"),
                       let v = UInt32(String(s[(i + 3)..<close]), radix: 16), let scalar = Unicode.Scalar(v) {
                        out.unicodeScalars.append(scalar); i = close + 1
                    } else { out.append("u"); i += 2 }
                default: out.append(n); i += 2
                }
                continue
            }
            out.append(c); i += 1
        }
        return nil
    }

    /// Index of the `)` that closes the `(` at `openAt`, skipping strings and comments.
    static func closingParen(_ s: [Character], openAt: Int) -> Int? {
        guard openAt < s.count, s[openAt] == "(" else { return nil }
        var depth = 0, i = openAt
        while i < s.count {
            let c = s[i]
            if c == "\"" {
                guard let r = readString(s, at: i) else { i += 1; continue }
                i = r.end; continue
            }
            if c == "/", i + 1 < s.count {
                if s[i + 1] == "/" { while i < s.count, s[i] != "\n" { i += 1 }; continue }
                if s[i + 1] == "*" {
                    i += 2
                    while i + 1 < s.count, !(s[i] == "*" && s[i + 1] == "/") { i += 1 }
                    i += 2; continue
                }
            }
            if c == "(" { depth += 1 }
            if c == ")" { depth -= 1; if depth == 0 { return i } }
            i += 1
        }
        return nil
    }

    /// The arguments of a call, split at top-level commas. `label` is nil for unlabelled arguments.
    static func arguments(_ inner: [Character]) -> [(label: String?, value: [Character])] {
        var parts: [[Character]] = [], current: [Character] = []
        var depth = 0, i = 0
        while i < inner.count {
            let c = inner[i]
            if c == "\"", let r = readString(inner, at: i) { current += inner[i..<r.end]; i = r.end; continue }
            if c == "/", i + 1 < inner.count, inner[i + 1] == "/" {
                while i < inner.count, inner[i] != "\n" { i += 1 }
                continue
            }
            if c == "(" || c == "[" || c == "{" { depth += 1 }
            if c == ")" || c == "]" || c == "}" { depth -= 1 }
            if c == ",", depth == 0 { parts.append(current); current = []; i += 1; continue }
            current.append(c); i += 1
        }
        if !current.allSatisfy({ $0.isWhitespace }) { parts.append(current) }
        return parts.map { raw in
            var j = 0
            while j < raw.count, raw[j].isWhitespace { j += 1 }
            var k = j
            while k < raw.count, raw[k].isLetter || raw[k].isNumber || raw[k] == "_" { k += 1 }
            if k > j, k < raw.count, raw[k] == ":" {
                return (String(raw[j..<k]), Array(raw[(k + 1)...]))
            }
            return (nil, raw)
        }
    }

    /// All top-level string literals of an expression, concatenated (so `"a" + "b"` becomes `ab`).
    static func joinedStrings(_ expr: [Character]) -> String? {
        var out = "", found = false, i = 0
        while i < expr.count {
            if expr[i] == "\"", let r = readString(expr, at: i) { out += r.text; found = true; i = r.end } else { i += 1 }
        }
        return found ? out : nil
    }

    /// Every string literal in an expression, in order (for an array like `["a", "b"]`).
    static func allStrings(_ expr: [Character]) -> [String] {
        var out: [String] = [], i = 0
        while i < expr.count {
            if expr[i] == "\"", let r = readString(expr, at: i) { out.append(r.text); i = r.end } else { i += 1 }
        }
        return out
    }

    /// Finds `name(` at a word boundary and returns the arguments inside each call, with the character offset of the call.
    static func calls(named name: String, in s: [Character]) -> [(offset: Int, args: [(label: String?, value: [Character])])] {
        let n = Array(name)
        var out: [(Int, [(label: String?, value: [Character])])] = []
        var i = 0
        while i + n.count < s.count {
            if s[i] == "\"", let r = readString(s, at: i) { i = r.end; continue }
            if s[i] == "/", i + 1 < s.count, s[i + 1] == "/" {
                while i < s.count, s[i] != "\n" { i += 1 }
                continue
            }
            if s[i] == n[0], Array(s[i..<(i + n.count)]) == n, s[i + n.count] == "(" {
                let before: Character = i > 0 ? s[i - 1] : " "
                let boundary = !(before.isLetter || before.isNumber || before == "_")
                if boundary, let close = closingParen(s, openAt: i + n.count) {
                    out.append((i, arguments(Array(s[(i + n.count + 1)..<close]))))
                    i += n.count + 1       // continue inside, so nested calls are found too
                    continue
                }
            }
            i += 1
        }
        return out
    }

    static func string(_ args: [(label: String?, value: [Character])], _ label: String) -> String? {
        args.first { $0.label == label }.flatMap { joinedStrings($0.value) }
    }
}
