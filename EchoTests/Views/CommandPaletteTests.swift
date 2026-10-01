import Testing
@testable import Echo

@Suite("Command palette matching")
struct CommandPaletteMatcherTests {
    @Test func prefixBeatsWordStartBeatsSubstringBeatsSubsequence() throws {
        let prefix = try #require(CommandPaletteMatcher.score("new", title: "New Query in prod"))
        let wordStart = try #require(CommandPaletteMatcher.score("query", title: "New Query in prod"))
        let substring = try #require(CommandPaletteMatcher.score("uer", title: "New Query in prod"))
        let subsequence = try #require(CommandPaletteMatcher.score("nqp", title: "New Query in prod"))
        #expect(prefix > wordStart && wordStart > substring && substring > subsequence)
    }

    @Test func ignoresCase() {
        #expect(CommandPaletteMatcher.score("RUN", title: "Run Statement at Cursor") != nil)
    }

    @Test func keywordsMatchHiddenWords() {
        #expect(CommandPaletteMatcher.score("use", title: "Switch Database to sales", keywords: "use database sales") != nil)
    }

    @Test func missingLettersDontMatch() {
        #expect(CommandPaletteMatcher.score("xyz", title: "Explain") == nil)
    }
}

@Suite("Command palette model")
@MainActor
struct CommandPaletteModelTests {
    private func item(_ title: String, _ section: CommandPaletteItem.Section) -> CommandPaletteItem {
        CommandPaletteItem(id: title, section: section, title: title, subtitle: nil, systemImage: "circle", perform: {})
    }

    @Test func emptyQueryShowsActionsAndTabsOnly() {
        let model = CommandPaletteModel()
        model.localItems = [item("Snippet", .snippets), item("Query 1", .tabs), item("Run", .actions)]
        #expect(model.results.map(\.title) == ["Run", "Query 1"])
    }

    @Test func resultsAreGroupedBySectionAndCapped() {
        let model = CommandPaletteModel()
        model.localItems = (0..<10).map { item("select \($0)", .snippets) } + [item("select tab", .tabs)]
        model.query = "select"
        let rows = model.results
        #expect(rows.first?.section == .tabs)
        #expect(rows.filter { $0.section == .snippets }.count == CommandPaletteModel.rowsPerSection)
    }

    @Test func selectionWrapsAndPerforms() {
        var performed: [String] = []
        let model = CommandPaletteModel()
        model.localItems = ["A", "B"].map { title in
            CommandPaletteItem(id: title, section: .actions, title: title, subtitle: nil, systemImage: "circle") { performed.append(title) }
        }
        model.moveSelection(by: -1)
        #expect(model.performSelected())
        #expect(performed == ["B"])
    }

    @Test func selectionFollowsTheRowWhenRowsArriveAboveIt() {
        var performed: [String] = []
        let model = CommandPaletteModel()
        let make: (String) -> CommandPaletteItem = { title in
            CommandPaletteItem(id: title, section: .actions, title: title, subtitle: nil, systemImage: "circle") { performed.append(title) }
        }
        model.localItems = [make("Beta"), make("Gamma")]
        model.moveSelection(by: 1)
        model.localItems.insert(make("Alpha"), at: 0)
        #expect(model.performSelected())
        #expect(performed == ["Gamma"])
    }

    @Test func typingSelectsTheFirstRowAgain() {
        let model = CommandPaletteModel()
        model.localItems = [item("Run", .actions), item("Rollback", .actions)]
        model.moveSelection(by: 1)
        model.query = "r"
        #expect(model.selectedID == nil)
        #expect(model.selectedIndex(in: model.results) == 0)
    }
}
