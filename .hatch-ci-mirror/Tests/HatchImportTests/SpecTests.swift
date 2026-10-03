import XCTest
import HatchCore
@testable import HatchImport

final class SpecTests: XCTestCase {
    // MARK: Parse

    func testParsesFixture() throws {
        let text = try String(contentsOf: Paths.fixtures.appendingPathComponent("spec/notifications.md"), encoding: .utf8)
        let doc = SpecMarkdown.parse(text)
        XCTAssertEqual(doc.prefix, "NOTIF")
        XCTAssertEqual(doc.entries.map(\.code), ["NOTIF-1.1", "NOTIF-1.2", "NOTIF-2.1", "TABS-1.1"])
        XCTAssertEqual(doc.entries[1].text, "Toast padding is 12pt on all sides and 16pt when the message has an action.")
        XCTAssertEqual(doc.entries[1].area, "Notifications")
        XCTAssertEqual(doc.entries[3].area, "Tabs")
        XCTAssertEqual(doc.warnings.count, 1, "TABS-1.1 does not start with the NOTIF prefix: \(doc.warnings)")
    }

    func testNoFrontMatterNoHeading() {
        let doc = SpecMarkdown.parse("- A-1: first\n- A-2: second\n")
        XCTAssertNil(doc.prefix)
        XCTAssertEqual(doc.entries.map(\.area), [nil, nil])
        XCTAssertEqual(doc.entries.count, 2)
    }

    func testBulletStylesAndBoldCodes() {
        let doc = SpecMarkdown.parse("# X\n* X-1: star\n+ X-2: plus\n- **X-3**: bold\n- **X-4:** bold both\n")
        XCTAssertEqual(doc.entries.map(\.code), ["X-1", "X-2", "X-3", "X-4"])
        XCTAssertEqual(doc.entries[3].text, "bold both")
    }

    func testTextMayContainColonsAndCodes() {
        let doc = SpecMarkdown.parse("- NOTIF-3.1: Ratio is 16:9, see NOTIF-3.2: it overrides\n")
        XCTAssertEqual(doc.entries.first?.text, "Ratio is 16:9, see NOTIF-3.2: it overrides")
    }

    func testBlankLineEndsContinuation() {
        let doc = SpecMarkdown.parse("- A-1: one\n  more\n\n  not part of it\n- A-2: two\n")
        XCTAssertEqual(doc.entries[0].text, "one more")
        XCTAssertEqual(doc.entries.count, 2)
    }

    func testNestedBulletIsContinuation() {
        let doc = SpecMarkdown.parse("- A-1: one\n  - detail\n")
        XCTAssertEqual(doc.entries[0].text, "one - detail")
    }

    func testDuplicateCodeLastWinsWithWarning() {
        let doc = SpecMarkdown.parse("- A-1: old\n- A-1: new\n")
        XCTAssertEqual(doc.entries.map(\.text), ["new"])
        XCTAssertTrue(doc.warnings.first?.contains("already defined") ?? false)
    }

    func testBadLinesBecomeWarningsNotCrashes() {
        let doc = SpecMarkdown.parse("- no code here\n- a-1: lowercase\n- A-1:\n- A-2: ok\n- A-: nope\n- A-1.: nope\n")
        XCTAssertEqual(doc.entries.map(\.code), ["A-2"])
        XCTAssertFalse(doc.warnings.isEmpty)
    }

    func testFencedCodeIsIgnored() {
        let doc = SpecMarkdown.parse("# A\n```\n- A-1: inside\n```\n- A-2: outside\n")
        XCTAssertEqual(doc.entries.map(\.code), ["A-2"])
    }

    func testWindowsLineEndingsAndUnclosedFrontMatter() {
        let doc = SpecMarkdown.parse("---\r\nprefix: A\r\n---\r\n# Area\r\n- A-1: one\r\n  two\r\n")
        XCTAssertEqual(doc.prefix, "A")
        XCTAssertEqual(doc.entries.first?.text, "one two")
        let open = SpecMarkdown.parse("---\nprefix: A\n- A-1: x\n")
        XCTAssertNil(open.prefix)
        XCTAssertEqual(open.entries.count, 1)
        XCTAssertTrue(open.warnings.contains { $0.contains("front matter") })
    }

    func testQuotedPrefixAndSubheadings() {
        let doc = SpecMarkdown.parse("---\nprefix: \"Q\"\n---\n# Area\n## Sub heading\n- Q-1: a\n")
        XCTAssertEqual(doc.prefix, "Q")
        XCTAssertEqual(doc.entries.first?.area, "Area")
    }

    func testEmptyAndGarbageInput() {
        XCTAssertEqual(SpecMarkdown.parse("").entries.count, 0)
        XCTAssertEqual(SpecMarkdown.parse("\u{0}\u{1}# \n---\n").entries.count, 0)
    }

    func testIsCode() {
        for ok in ["NOTIF-1.2", "A-1", "TABS-2.7", "R2D2-10.4.1", "EDT-1"] { XCTAssertTrue(SpecMarkdown.isCode(ok), ok) }
        for bad in ["", "notif-1", "NOTIF", "NOTIF-", "NOTIF-1.", "NOTIF-a", "1A-1", "A B-1", "-1"] { XCTAssertFalse(SpecMarkdown.isCode(bad), bad) }
    }

    func testRenderRoundTrip() {
        let entries = [SpecEntry(code: "A-1", area: "One", text: "alpha"), SpecEntry(code: "A-2", area: "One", text: "beta\ngamma"),
                       SpecEntry(code: "A-3", area: "Two", text: "delta")]
        let doc = SpecMarkdown.parse(SpecMarkdown.render(prefix: "A", entries: entries))
        XCTAssertEqual(doc.prefix, "A")
        XCTAssertEqual(doc.entries.map(\.code), ["A-1", "A-2", "A-3"])
        XCTAssertEqual(doc.entries.map(\.area), ["One", "One", "Two"])
        XCTAssertEqual(doc.entries[1].text, "beta gamma")
        XCTAssertTrue(doc.warnings.isEmpty)
    }

    // MARK: Indexer

    func testIndexerUpsertsAndSearches() throws {
        let (store, project) = try makeStore()
        let r = try SpecIndexer.index(directory: Paths.fixtures.appendingPathComponent("spec"), project: project, store: store)
        XCTAssertEqual(r.files, 1)
        XCTAssertEqual(r.items, 4)
        let items = try store.specItems(projectId: project.id)
        XCTAssertEqual(items.map(\.code), ["NOTIF-1.1", "NOTIF-1.2", "NOTIF-2.1", "TABS-1.1"])
        XCTAssertEqual(items.first?.source, ".hatch/spec/notifications.md")
        XCTAssertEqual(try store.specItems(projectId: project.id, area: "Tabs").count, 1)
        XCTAssertEqual(try store.searchSpec(projectId: project.id, query: "padding").map(\.code), ["NOTIF-1.2"])
    }

    func testIndexerRemovesStaleItemsButKeepsOtherSources() throws {
        let (store, project) = try makeStore()
        let dir = try tempDir("spec")
        try "# A\n- A-1: one\n- A-2: two\n".write(to: dir.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
        try store.upsertSpecItems(projectId: project.id, items: [("HAND-1", "Manual", "typed in by hand", nil)])
        _ = try SpecIndexer.index(directory: dir, project: project, store: store)
        XCTAssertEqual(try store.specItems(projectId: project.id).map(\.code), ["A-1", "A-2", "HAND-1"])

        try "# A\n- A-1: one changed\n".write(to: dir.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
        let r = try SpecIndexer.index(directory: dir, project: project, store: store)
        XCTAssertEqual(r.removed, ["A-2"])
        XCTAssertEqual(try store.specItems(projectId: project.id).map(\.code), ["A-1", "HAND-1"])
        XCTAssertEqual(try store.specItems(projectId: project.id).first?.text, "one changed")
        XCTAssertTrue(try store.searchSpec(projectId: project.id, query: "two").isEmpty, "the search index forgets removed items")

        try FileManager.default.removeItem(at: dir.appendingPathComponent("a.md"))
        XCTAssertEqual(try SpecIndexer.index(directory: dir, project: project, store: store).removed, ["A-1"])
    }

    func testIndexerIsIdempotentAndHandlesMissingDirectory() throws {
        let (store, project) = try makeStore()
        let dir = Paths.fixtures.appendingPathComponent("spec")
        _ = try SpecIndexer.index(directory: dir, project: project, store: store)
        let before = try store.specItems(projectId: project.id)
        let again = try SpecIndexer.index(directory: dir, project: project, store: store)
        XCTAssertEqual(again.removed, [])
        XCTAssertEqual(try store.specItems(projectId: project.id), before)
        let none = try SpecIndexer.index(directory: URL(fileURLWithPath: "/nonexistent/spec"), project: project, store: store)
        XCTAssertEqual(none.files, 0)
    }

    func testSameCodeInTwoFilesWarns() throws {
        let (store, project) = try makeStore()
        let dir = try tempDir("spec")
        try "- A-1: from a\n".write(to: dir.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
        try "- A-1: from b\n".write(to: dir.appendingPathComponent("b.md"), atomically: true, encoding: .utf8)
        let r = try SpecIndexer.index(directory: dir, project: project, store: store)
        XCTAssertEqual(r.items, 1)
        XCTAssertTrue(r.warnings.contains { $0.contains("also in a.md") })
        XCTAssertEqual(try store.specItems(projectId: project.id).first?.text, "from b")
    }

    // MARK: Exporter

    private let swiftFixture = #"""
    enum DemoArea {
        static let area = LabArea(id: "demo", title: "Demo area", symbol: "x", summary: "s")
        // SpecElement(number: "9.9", name: "Commented out", summary: "no")
        static let spec = AreaSpec(code: "DMO", stageHeight: 100, parts: parts) { Text("x") }
        static let parts: [SpecPart] = [
            SpecPart(number: "1", name: "Strip", summary: "The band.", elements: [
                SpecElement(number: "1.1", name: "Card", summary: "Opaque " + "card.", groups: [
                    .material(.row("Fill", "opaque", token: "Colors.card"), .row("Glass", "none")),
                    .behaviour(.row("Says \"hi\"", "with (parens) inside")),
                ], rounds: ["decided.x", "ongoing.y-r1"], files: ["a.swift"]),
                SpecElement(number: "1.2", name: "Old", summary: "Gone.", isRetired: true),
                SpecElement(number: "1.2", name: "Duplicate", summary: "ignored"),
            ]),
            SpecPart(number: "2", name: "Rest", summary: "", elements: [
                SpecElement(name: "no number", summary: "skipped"),
                SpecElement(number: "2.1", name: "Last", summary: "Done"),
            ]),
        ]
    }
    """#

    func testExtractsElementsRowsAndRounds() throws {
        let area = try XCTUnwrap(SpecExporter.extract(source: swiftFixture, fallbackTitle: "Fallback"))
        XCTAssertEqual(area.code, "DMO")
        XCTAssertEqual(area.title, "Demo area")
        XCTAssertEqual(area.entries.map(\.code), ["DMO-1.1", "DMO-1.2", "DMO-2.1"])
        XCTAssertEqual(area.retired, 1)
        XCTAssertEqual(area.warnings.count, 2)
        let first = area.entries[0].text.components(separatedBy: "\n")
        XCTAssertEqual(first[0], "Card. Opaque card.")
        XCTAssertTrue(first.contains("Material · Fill: opaque (token Colors.card)"))
        XCTAssertTrue(first.contains("Behaviour · Says \"hi\": with (parens) inside"))
        XCTAssertEqual(first.last, "Shaped by: decided.x, ongoing.y-r1")
        XCTAssertTrue(area.entries[1].text.hasPrefix("(retired) "))
    }

    func testExportedMarkdownParsesBack() throws {
        let area = try XCTUnwrap(SpecExporter.extract(source: swiftFixture, fallbackTitle: "Fallback"))
        let doc = SpecMarkdown.parse(SpecExporter.markdown(area))
        XCTAssertEqual(doc.prefix, "DMO")
        XCTAssertEqual(doc.entries.map(\.code), area.entries.map(\.code))
        XCTAssertEqual(Set(doc.entries.compactMap(\.area)), ["Demo area"])
        XCTAssertTrue(doc.warnings.isEmpty, "\(doc.warnings)")
        XCTAssertTrue(doc.entries[0].text.contains("Fill: opaque"))
    }

    func testExtractFromNothing() {
        XCTAssertNil(SpecExporter.extract(source: "", fallbackTitle: "x"))
        XCTAssertNil(SpecExporter.extract(source: "AreaSpec(code: ", fallbackTitle: "x"))
        XCTAssertNil(SpecExporter.extract(source: "let s = \"AreaSpec(code: \\\"X\\\"\"", fallbackTitle: "x"))
        XCTAssertEqual(SpecExporter.extractAll(areasDirectory: URL(fileURLWithPath: "/nonexistent")).count, 0)
    }

    func testExportsTheRealEchoLabSpecs() throws {
        try requireEcho(Paths.areas)
        let areas = SpecExporter.extractAll(areasDirectory: Paths.areas)
        let count = areas.map(\.entries.count).reduce(0, +)
        XCTAssertEqual(areas.map(\.code).sorted(), ["CON", "EDT", "FND", "FTR", "INS", "NTF", "SNS", "TABS", "TLT", "TREE", "WIN"])
        XCTAssertEqual(count, 233, "225 SpecElement(number:) calls plus 8 rule(...) helper calls in Foundations")
        XCTAssertTrue(areas.allSatisfy { $0.warnings.isEmpty }, "\(areas.flatMap(\.warnings))")
        let all = areas.flatMap(\.entries)
        XCTAssertEqual(Set(all.map(\.code)).count, all.count, "ids are unique")
        XCTAssertTrue(all.contains { $0.code == "TABS-2.7" })
        XCTAssertEqual(areas.map(\.retired).reduce(0, +), 3)

        // And the Markdown parses back to the same ids, and indexes.
        let dir = try tempDir("export")
        let urls = try SpecExporter.write(areas, to: dir)
        XCTAssertEqual(urls.count, areas.count)
        let (store, project) = try makeStore()
        let result = try SpecIndexer.index(directory: dir, project: project, store: store)
        XCTAssertEqual(result.items, count)
        XCTAssertTrue(result.warnings.isEmpty, "\(result.warnings.prefix(5))")
        XCTAssertFalse(try store.searchSpec(projectId: project.id, query: "gutter").isEmpty)
    }
}
