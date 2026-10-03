import Foundation

/// What Echo Labs knows about a page that `lab-state.json` does not: its title, group and the round it belongs to.
/// Echo Labs keeps these in Swift source (`LabRounds.swift`, `OngoingPages.swift`), so we read them with a tolerant scanner.
public struct LabCatalog: Equatable, Sendable {
    public struct Round: Equatable, Sendable {
        public var id: String, label: String, title: String, date: String, asked: String, outcome: String
        public var pageIDs: [String]
    }
    public struct Page: Equatable, Sendable {
        public var id: String
        public var group: String?
        public var title: String?
        public var summary: String?
    }

    public var rounds: [Round]
    public var pages: [String: Page]

    public static let empty = LabCatalog(rounds: [], pages: [:])
    public init(rounds: [Round] = [], pages: [String: Page] = [:]) { self.rounds = rounds; self.pages = pages }

    public func round(forPage id: String) -> Round? { rounds.first { $0.pageIDs.contains(id) } }

    /// Reads `<sourcesRoot>/Rounds/LabRounds.swift` and every Swift file under the root that declares pages. Missing files give an empty catalog.
    public static func load(echoLabSources root: URL) -> LabCatalog {
        var catalog = LabCatalog()
        if let text = try? String(contentsOf: root.appendingPathComponent("Rounds/LabRounds.swift"), encoding: .utf8) {
            catalog.rounds = parseRounds(text)
        }
        let fm = FileManager.default
        if let walker = fm.enumerator(at: root, includingPropertiesForKeys: nil) {
            for case let url as URL in walker where url.pathExtension == "swift" {
                guard let text = try? String(contentsOf: url, encoding: .utf8), text.contains("group:") else { continue }
                for page in parsePages(text) where catalog.pages[page.id] == nil { catalog.pages[page.id] = page }
            }
        }
        return catalog
    }

    /// `Info(id: "r28", label: ..., title: ..., asked: ..., outcome: ..., pageIDs: [...])` entries. Entries without an id are skipped.
    public static func parseRounds(_ source: String) -> [Round] {
        var out: [Round] = []
        for call in SwiftSource.calls(named: "Info", in: Array(source)) {
            guard let id = SwiftSource.string(call.args, "id") else { continue }
            let pageIDs = call.args.first { $0.label == "pageIDs" }.map { SwiftSource.allStrings($0.value) } ?? []
            out.append(Round(id: id, label: SwiftSource.string(call.args, "label") ?? id,
                             title: SwiftSource.string(call.args, "title") ?? id,
                             date: SwiftSource.string(call.args, "date") ?? "",
                             asked: SwiftSource.string(call.args, "asked") ?? "",
                             outcome: SwiftSource.string(call.args, "outcome") ?? "",
                             pageIDs: pageIDs))
        }
        return out
    }

    /// `id: "ongoing.x", group: "Editor and running", title: "... · round 21", ... summary: "..."`.
    /// The round suffix in the title (" · round 21") is dropped because the ticket number replaces it.
    public static func parsePages(_ source: String) -> [Page] {
        let chars = Array(source)
        var out: [Page] = []
        for call in SwiftSource.calls(named: "round", in: chars) + SwiftSource.calls(named: "page", in: chars) + SwiftSource.calls(named: "LabPage", in: chars) {
            guard let id = SwiftSource.string(call.args, "id") else { continue }
            var title = SwiftSource.string(call.args, "title")
            if let t = title, let r = t.range(of: " · round", options: .caseInsensitive) { title = String(t[..<r.lowerBound]) }
            out.append(Page(id: id, group: SwiftSource.string(call.args, "group"), title: title, summary: SwiftSource.string(call.args, "summary")))
        }
        return out
    }
}
