import Foundation

/// One Spec line: an id and the text that is true now.
public struct SpecEntry: Equatable, Sendable {
    public var code: String
    public var area: String?
    public var text: String
    public init(code: String, area: String?, text: String) { self.code = code; self.area = area; self.text = text }
}

public struct SpecDocument: Equatable, Sendable {
    /// From the optional front matter (`prefix: NOTIF`).
    public var prefix: String?
    public var entries: [SpecEntry]
    public var warnings: [String]
}

/// The Markdown format of `.hatch/spec/*.md` (decision L3). Plain text so people, agents and diffs can all read it:
///
///     ---
///     prefix: NOTIF
///     ---
///     # Notifications
///     - NOTIF-1.2: Toast padding is 12pt on all sides
///       and a continuation line is indented.
///
/// `# Heading` sets the area. `##` and deeper headings are only for reading. Lines that are not list items are prose and ignored.
public enum SpecMarkdown {
    /// Reads a spec file. Never throws: odd lines become warnings with their line numbers.
    public static func parse(_ source: String) -> SpecDocument {
        let lines = source.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
        var doc = SpecDocument(prefix: nil, entries: [], warnings: [])
        var i = 0
        if lines.first?.trimmingCharacters(in: .whitespaces) == "---" {
            if let end = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) {
                for l in lines[1..<end] {
                    guard let colon = l.firstIndex(of: ":") else { continue }
                    let key = l[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
                    let value = l[l.index(after: colon)...].trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    if key == "prefix", !value.isEmpty { doc.prefix = value }
                }
                i = end + 1
            } else {
                doc.warnings.append("line 1: front matter is never closed; ignored")
            }
        }
        var area: String?
        var current: (code: String, area: String?, text: String, line: Int)?
        var inFence = false
        var seen: [String: Int] = [:]

        func flush() {
            guard let c = current else { return }
            current = nil
            let text = c.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { doc.warnings.append("line \(c.line): \(c.code) has no text; skipped"); return }
            if let first = seen[c.code] { doc.warnings.append("line \(c.line): \(c.code) was already defined on line \(first); the later line wins")
                doc.entries.removeAll { $0.code == c.code } }
            seen[c.code] = c.line
            if let p = doc.prefix, !c.code.hasPrefix(p + "-") { doc.warnings.append("line \(c.line): \(c.code) does not start with the prefix \(p)-") }
            doc.entries.append(SpecEntry(code: c.code, area: c.area, text: text))
        }

        while i < lines.count {
            let line = lines[i], number = i + 1
            i += 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") { flush(); inFence.toggle(); continue }
            if inFence { continue }
            if trimmed.isEmpty { flush(); continue }
            if line.hasPrefix("#") {
                flush()
                let hashes = line.prefix(while: { $0 == "#" }).count
                if hashes == 1 {
                    let name = line.dropFirst().trimmingCharacters(in: .whitespaces)
                    area = name.isEmpty ? nil : name
                }
                continue
            }
            let indented = line.hasPrefix(" ") || line.hasPrefix("\t")
            if indented, current != nil {
                current!.text += " " + trimmed
                continue
            }
            if let item = parseItem(trimmed) {
                flush()
                current = (item.code, area, item.text, number)
                continue
            }
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                flush()
                doc.warnings.append("line \(number): a list item without a code like ABC-1.2: was ignored")
                continue
            }
            flush()   // prose between items
        }
        flush()
        return doc
    }

    /// `- NOTIF-1.2: text` (also `*` and `+` bullets). A code is capital letters and digits, a dash, then dotted numbers.
    static func parseItem(_ trimmed: String) -> (code: String, text: String)? {
        guard let bullet = trimmed.first, "-*+".contains(bullet), trimmed.dropFirst().first == " " else { return nil }
        var rest = Substring(trimmed.dropFirst(2)).drop(while: { $0 == " " })
        if rest.hasPrefix("**") { rest = rest.dropFirst(2) }   // tolerate **CODE**: text
        guard let colon = rest.firstIndex(of: ":") else { return nil }
        let code = rest[..<colon].replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
        guard isCode(code) else { return nil }
        var text = rest[rest.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("**") { text = text.dropFirst(2).trimmingCharacters(in: .whitespaces) }
        return (code, text)
    }

    public static func isCode(_ s: String) -> Bool {
        let parts = s.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, let f = parts[0].first, f.isASCII, f.isUppercase,
              parts[0].allSatisfy({ $0.isASCII && ($0.isUppercase || $0.isNumber) }) else { return false }
        let nums = parts[1].split(separator: ".", omittingEmptySubsequences: false)
        return !nums.isEmpty && nums.allSatisfy { !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isNumber } }
    }

    /// Writes entries back out in the format above, grouped by area in first-seen order.
    public static func render(prefix: String?, entries: [SpecEntry]) -> String {
        var out = ""
        if let prefix { out += "---\nprefix: \(prefix)\n---\n" }
        var order: [String?] = []
        for e in entries where !order.contains(where: { $0 == e.area }) { order.append(e.area) }
        for area in order {
            if let area { out += (out.isEmpty ? "" : "\n") + "# \(area)\n\n" } else if !out.isEmpty { out += "\n" }
            for e in entries where e.area == area {
                let lines = e.text.components(separatedBy: "\n")
                out += "- \(e.code): \(lines[0])\n"
                for l in lines.dropFirst() where !l.trimmingCharacters(in: .whitespaces).isEmpty { out += "  \(l)\n" }
            }
        }
        return out
    }
}
