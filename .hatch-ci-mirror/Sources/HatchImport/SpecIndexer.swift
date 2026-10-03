import Foundation
import HatchCore

public struct SpecIndexResult: Equatable, Sendable {
    public var files = 0
    public var items = 0
    /// Codes that were in the index but no longer appear in any file.
    public var removed: [String] = []
    public var warnings: [String] = []
}

/// Reads `.hatch/spec/*.md` into the Spec search index (decision L3).
public enum SpecIndexer {
    /// Spec items from these files are stored with `source` = `.hatch/spec/<file>`. The same prefix is used to find stale items.
    public static let sourcePrefix = ".hatch/spec/"

    /// Upserts every item and removes items of earlier runs whose line has disappeared. Items from other sources
    /// (for example typed in by hand) are left alone. Re-running with unchanged files changes nothing.
    @discardableResult
    public static func index(directory: URL, project: Project, store: HatchStore) throws -> SpecIndexResult {
        var result = SpecIndexResult()
        let fm = FileManager.default
        let names = ((try? fm.contentsOfDirectory(atPath: directory.path)) ?? []).filter { $0.hasSuffix(".md") }.sorted()
        var items: [(code: String, area: String?, text: String, source: String?)] = []
        var owner: [String: String] = [:]
        for name in names {
            guard let text = try? String(contentsOf: directory.appendingPathComponent(name), encoding: .utf8) else {
                result.warnings.append("\(name): cannot be read as UTF-8; skipped"); continue
            }
            result.files += 1
            let doc = SpecMarkdown.parse(text)
            result.warnings += doc.warnings.map { "\(name): \($0)" }
            for e in doc.entries {
                if let other = owner[e.code] {
                    result.warnings.append("\(name): \(e.code) is also in \(other); this file wins")
                    items.removeAll { $0.code == e.code }
                }
                owner[e.code] = name
                items.append((e.code, e.area, e.text, sourcePrefix + name))
            }
        }
        try store.db.transaction {
            try store.upsertSpecItems(projectId: project.id, items: items)
            result.removed = try store.deleteSpecItems(projectId: project.id, sourcePrefix: sourcePrefix, notIn: Set(items.map(\.code)))
        }
        result.items = items.count
        return result
    }
}
