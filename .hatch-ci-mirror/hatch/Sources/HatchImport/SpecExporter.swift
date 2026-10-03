import Foundation

/// A part (section) of an Echo Labs area spec, kept only for headings.
public struct ExportedPart: Equatable, Sendable {
    public var number: String, name: String, summary: String
}

/// One Echo Labs area spec: `AreaSpec(code: "EDT", ...)` with its parts and elements.
public struct ExportedArea: Equatable, Sendable {
    public var code: String
    public var title: String
    public var parts: [ExportedPart]
    /// Element ids are `<code>-<element number>`, for example `EDT-1.2`.
    public var entries: [SpecEntry]
    public var retired: Int
    public var warnings: [String]
}

/// Converts Echo Labs' Swift specs (`Areas/<Name>/<Name>Spec.swift`) to the Markdown format of `SpecMarkdown`.
/// It reads the source text and never compiles it, so it keeps working while Echo Labs changes.
public enum SpecExporter {
    /// Reads one area's Swift text. `fallbackTitle` is used when no `LabArea(title:)` is found. Returns nil when no spec is declared.
    public static func extract(source: String, fallbackTitle: String) -> ExportedArea? {
        let chars = Array(source)
        guard let code = SwiftSource.calls(named: "AreaSpec", in: chars).compactMap({ SwiftSource.string($0.args, "code") }).first,
              !code.isEmpty else { return nil }
        let title = SwiftSource.calls(named: "LabArea", in: chars).compactMap { SwiftSource.string($0.args, "title") }.first ?? fallbackTitle
        var area = ExportedArea(code: code, title: title, parts: [], entries: [], retired: 0, warnings: [])
        for part in SwiftSource.calls(named: "SpecPart", in: chars) {
            guard let n = SwiftSource.string(part.args, "number") else { continue }
            area.parts.append(ExportedPart(number: n, name: SwiftSource.string(part.args, "name") ?? "", summary: SwiftSource.string(part.args, "summary") ?? ""))
        }
        // Direct `SpecElement(number: "1.1", ...)` calls, and calls of helpers such as `rule("1.1", "Name", "Why")`
        // declared as `func rule(...) -> SpecElement` (Foundations uses one).
        var elements: [(offset: Int, args: [(label: String?, value: [Character])])] = SwiftSource.calls(named: "SpecElement", in: chars)
        for helper in helperNames(source) {
            for call in SwiftSource.calls(named: helper, in: chars) where call.args.count >= 2 && call.args.allSatisfy({ $0.label == nil }) {
                guard let number = SwiftSource.joinedStrings(call.args[0].value), !number.isEmpty else { continue }
                var args: [(label: String?, value: [Character])] = [("number", call.args[0].value), ("name", call.args[1].value)]
                if call.args.count > 2 { args.append(("summary", call.args[2].value)) }
                elements.append((call.offset, args))
            }
        }
        var seen = Set<String>()
        for el in elements.sorted(by: { $0.offset < $1.offset }) {
            guard let n = SwiftSource.string(el.args, "number") else {
                // `number: number` inside a helper's body is the template, not an element.
                if el.args.first(where: { $0.label == "number" }) == nil { area.warnings.append("an element without a number was skipped") }
                continue
            }
            let id = "\(code)-\(n)"
            guard SpecMarkdown.isCode(id) else { area.warnings.append("\(id) is not a valid id; skipped"); continue }
            guard seen.insert(id).inserted else { area.warnings.append("\(id) is declared twice; the first one is kept"); continue }
            let name = SwiftSource.string(el.args, "name") ?? ""
            let summary = SwiftSource.string(el.args, "summary") ?? ""
            let retired = el.args.first { $0.label == "isRetired" }.map { String($0.value).trimmingCharacters(in: .whitespaces) == "true" } ?? false
            if retired { area.retired += 1 }
            var lines = [(retired ? "(retired) " : "") + sentence(name, summary)]
            if let groups = el.args.first(where: { $0.label == "groups" }) { lines += rows(in: groups.value) }
            if let rounds = el.args.first(where: { $0.label == "rounds" }) {
                let ids = SwiftSource.allStrings(rounds.value)
                if !ids.isEmpty { lines.append("Shaped by: " + ids.joined(separator: ", ")) }
            }
            area.entries.append(SpecEntry(code: id, area: title, text: lines.joined(separator: "\n")))
        }
        return area
    }

    /// Goes through `<areasDirectory>/<Folder>/*.swift`. Folders without a spec are ignored. Areas come back in folder order.
    public static func extractAll(areasDirectory: URL) -> [ExportedArea] {
        let fm = FileManager.default
        var out: [ExportedArea] = []
        for folder in ((try? fm.contentsOfDirectory(atPath: areasDirectory.path)) ?? []).sorted() {
            let dir = areasDirectory.appendingPathComponent(folder)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { continue }
            let files = ((try? fm.contentsOfDirectory(atPath: dir.path)) ?? []).filter { $0.hasSuffix(".swift") }.sorted()
            // The area's title lives in `<Name>Area.swift`, the spec in `<Name>Spec.swift` or in the same file.
            let text = files.compactMap { try? String(contentsOf: dir.appendingPathComponent($0), encoding: .utf8) }
                .filter { $0.contains("SpecElement(") || $0.contains("AreaSpec(") || $0.contains("LabArea(") }
                .joined(separator: "\n")
            if var area = extract(source: text, fallbackTitle: folder) {
                area.warnings = area.warnings.map { "\(folder): \($0)" }
                out.append(area)
            }
        }
        return out
    }

    /// The Markdown file for one area. Parts become `##` headings, which the parser treats as reading aids.
    public static func markdown(_ area: ExportedArea) -> String {
        var out = "---\nprefix: \(area.code)\n---\n# \(area.title)\n"
        var lastPart: String?
        for e in area.entries {
            let number = String(e.code.dropFirst(area.code.count + 1))
            let part = String(number.split(separator: ".").first ?? "")
            if part != lastPart, let p = area.parts.first(where: { $0.number == part }) {
                out += "\n## \(p.number). \(p.name)\n"
                if !p.summary.isEmpty { out += "\n\(p.summary)\n" }
                out += "\n"
            }
            lastPart = part
            let lines = e.text.components(separatedBy: "\n")
            out += "- \(e.code): \(lines[0])\n"
            for l in lines.dropFirst() { out += "  \(l)\n" }
        }
        return out
    }

    /// Writes one `.md` per area into `directory` and returns the file URLs.
    @discardableResult
    public static func write(_ areas: [ExportedArea], to directory: URL) throws -> [URL] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var urls: [URL] = []
        for a in areas {
            let slug = String(a.title.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" }).split(separator: "-").joined(separator: "-")
            let url = directory.appendingPathComponent((slug.isEmpty ? a.code.lowercased() : slug) + ".md")
            try markdown(a).write(to: url, atomically: true, encoding: .utf8)
            urls.append(url)
        }
        return urls
    }

    // MARK: Helpers

    /// Names of functions declared as returning `SpecElement`.
    private static func helperNames(_ source: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: #"func\s+(\w+)\s*\([^)]*\)\s*->\s*SpecElement\b"#) else { return [] }
        let ns = source as NSString
        return re.matches(in: source, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range(at: 1)) }
    }

    private static func sentence(_ name: String, _ summary: String) -> String {
        if summary.isEmpty { return name }
        if name.isEmpty { return summary }
        let end = name.last.map { ".!?:".contains($0) } ?? false
        return name + (end ? " " : ". ") + summary
    }

    /// Group calls such as `.material(.row("Fill", "opaque", token: "X"))` become "Material · Fill: opaque (token X)".
    private static func rows(in groups: [Character]) -> [String] {
        let kinds = ["type": "Type", "layout": "Layout", "material": "Material", "states": "States", "motion": "Motion", "behaviour": "Behaviour"]
        var spans: [(offset: Int, title: String, text: [Character])] = []
        for (kind, title) in kinds {
            let k = Array(kind)
            var i = 0
            while i + k.count + 1 < groups.count {
                if groups[i] == "\"", let r = SwiftSource.readString(groups, at: i) { i = r.end; continue }
                if groups[i] == ".", Array(groups[(i + 1)..<(i + 1 + k.count)]) == k, groups[i + 1 + k.count] == "(",
                   let close = SwiftSource.closingParen(groups, openAt: i + 1 + k.count) {
                    spans.append((i, title, Array(groups[(i + 1 + k.count)...close])))
                    i = close + 1
                    continue
                }
                i += 1
            }
        }
        var out: [String] = []
        for span in spans.sorted(by: { $0.offset < $1.offset }) {
            for row in SwiftSource.calls(named: "row", in: span.text) {
                guard row.args.count >= 2, let label = SwiftSource.joinedStrings(row.args[0].value),
                      let value = SwiftSource.joinedStrings(row.args[1].value) else { continue }
                var line = "\(span.title) · \(label): \(value)"
                if let token = row.args.first(where: { $0.label == "token" }).flatMap({ SwiftSource.joinedStrings($0.value) }) { line += " (token \(token))" }
                out.append(line)
            }
        }
        return out
    }
}
