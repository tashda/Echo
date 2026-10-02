import AppKit
import Foundation
import Testing
@testable import Echo

@Suite("Tool tab pages in the tab bar")
struct TabUnfoldLayoutTests {
    private let ids = (0..<4).map { _ in UUID() }

    @Test func unfoldedTabTakesItsIdealWidthAndOthersShareTheRest() {
        let widths = TabUnfoldLayout.widths(tabIDs: ids, unfoldedID: ids[0], idealUnfoldedWidth: 400, equalWidth: 200, totalWidth: 800)
        #expect(widths[ids[0]] == 400)
        #expect(widths[ids[1]] == 400.0 / 3)
        #expect(abs(widths.values.reduce(0, +) - 800) < 0.001)
    }

    /// Round 49, FP1: the front tool tab may take the strip less an icon-only tab for each other tab.
    @Test func unfoldedTabLeavesTheOthersTheirIcons() {
        let widths = TabUnfoldLayout.widths(tabIDs: ids, unfoldedID: ids[1], idealUnfoldedWidth: 2_000, equalWidth: 200, totalWidth: 800)
        #expect(widths[ids[1]] == 800 - 3 * LayoutTokens.TabPages.iconOnlyWidth)
        #expect(widths[ids[0]] == LayoutTokens.TabPages.iconOnlyWidth)
    }

    @Test func squeezedTabsShowOnlyTheirIcon() {
        #expect(TabUnfoldLayout.isIconOnly(width: LayoutTokens.TabPages.iconOnlyWidth, isFront: false))
        #expect(!TabUnfoldLayout.isIconOnly(width: LayoutTokens.TabPages.iconOnlyWidth, isFront: true))
        #expect(!TabUnfoldLayout.isIconOnly(width: 200, isFront: false))
    }

    /// Round 49, FP4: pages that fit stay in the tab; pages that cannot fit take a row, never a menu.
    @Test func pagesFitTheTabOrTakeARow() {
        #expect(TabPagePlacement.resolve(idealWidth: 860, tabCount: 4, totalWidth: 980) == .inTab)
        #expect(TabPagePlacement.resolve(idealWidth: 861, tabCount: 4, totalWidth: 980) == .row)
        #expect(TabPagePlacement.resolve(idealWidth: 400, tabCount: 1, totalWidth: 300) == .row)
    }

    /// Round 36.1, RW1: exactly as wide as its title and pages, even when that is narrower.
    @Test func narrowerTabKeepsItsOwnWidth() {
        let widths = TabUnfoldLayout.widths(tabIDs: ids, unfoldedID: ids[0], idealUnfoldedWidth: 150, equalWidth: 200, totalWidth: 800)
        #expect(widths[ids[0]] == 150)
        #expect(widths[ids[2]] == 650.0 / 3)
    }

    @Test func noChangeWhenTheIdealIsTheEqualWidth() {
        #expect(TabUnfoldLayout.widths(tabIDs: ids, unfoldedID: ids[0], idealUnfoldedWidth: 200, equalWidth: 200, totalWidth: 800).isEmpty)
    }

    /// Round 36.1, SW1: a lone tool tab keeps its own width at the leading edge.
    @Test func aLoneTabKeepsItsOwnWidth() {
        #expect(TabUnfoldLayout.widths(tabIDs: [ids[0]], unfoldedID: ids[0], idealUnfoldedWidth: 420, equalWidth: 900, totalWidth: 900) == [ids[0]: 420])
    }

    @Test func aLoneTabWiderThanTheStripFillsIt() {
        #expect(TabUnfoldLayout.widths(tabIDs: [ids[0]], unfoldedID: ids[0], idealUnfoldedWidth: 600, equalWidth: 300, totalWidth: 300).isEmpty)
    }

    @Test func anUnknownTabChangesNothing() {
        #expect(TabUnfoldLayout.widths(tabIDs: ids, unfoldedID: UUID(), idealUnfoldedWidth: 400, equalWidth: 200, totalWidth: 800).isEmpty)
    }

    @MainActor
    @Test func idealWidthDoesNotDependOnTheShownPage() {
        let pages = ["Processes", "Waits", "I/O"]
        let width = TabPageChipsMetrics.idealWidth(title: "Activity Monitor", pages: pages)
        #expect(width > LayoutTokens.TabPages.tabChrome)
        #expect(width == TabPageChipsMetrics.idealWidth(title: "Activity Monitor", pages: pages))
        #expect(TabPageChipsMetrics.idealWidth(title: "Activity Monitor", pages: pages + ["Queries"]) > width)
    }

    @MainActor
    @Test func activityMonitorPagesPerEngine() {
        #expect(MSSQLActivityMonitorView.MSSQLActivitySection.allCases.first?.rawValue == "Processes")
        #expect(!PostgresActivityMonitorView.PostgresActivitySection.allCases.isEmpty)
        #expect(MySQLActivityMonitorView.MySQLActivitySection.allCases.first?.rawValue == "Overview")
    }
}

/// Round 49, FP3: shortened names and tighter pages make the long tools fit a 13-inch window.
@Suite("Tool tab pages: shortened names")
struct TabPageNamesTests {
    @Test func longNamesAreShortenedInTheTabAndWholeOnTheRow() {
        #expect(TabPageNames.label("Event Triggers", compact: true) == "Triggers")
        #expect(TabPageNames.label("Event Triggers", compact: false) == "Event Triggers")
        #expect(TabPageNames.label("Sessions", compact: true) == "Sessions")
    }

    @MainActor
    @Test func shortenedPagesAreNarrower() {
        #expect(TabPageChipsMetrics.chipWidth("Configuration", compact: true) < TabPageChipsMetrics.chipWidth("Configuration", compact: false))
    }

    /// PostgreSQL's Activity Monitor, the longest pages left after Advanced Objects was split, fits
    /// a 13-inch window's strip (980 pt) with three other tabs as icons.
    @MainActor
    @Test func postgresActivityMonitorFitsAThirteenInchWindow() {
        let pages = PostgresActivityMonitorView.PostgresActivitySection.allCases.map(\.rawValue)
        let ideal = TabPageChipsMetrics.idealWidth(title: "Activity Monitor", pages: pages)
        #expect(TabPagePlacement.resolve(idealWidth: ideal, tabCount: 4, totalWidth: 980) == .inTab)
    }
}

/// Round 49, AO2: Advanced Objects on PostgreSQL is four tools; every page is in exactly one.
@Suite("Advanced Objects tools")
struct PostgresAdvancedObjectsGroupTests {
    typealias Group = PostgresAdvancedObjectsViewModel.Group

    @Test func everyPageIsInExactlyOneTool() {
        let all = Group.allCases.flatMap(\.sections)
        #expect(all.count == PostgresAdvancedObjectsViewModel.Section.allCases.count)
        #expect(Set(all) == Set(PostgresAdvancedObjectsViewModel.Section.allCases))
    }

    @Test func aPageNamesItsTool() {
        #expect(Group.containing(.tablespaces) == .storage)
        #expect(Group.containing(.rules) == .programming)
        #expect(Group.containing(.casts) == .types)
    }

    @Test func noToolHasMoreThanFourPages() {
        #expect(Group.allCases.allSatisfy { $0.sections.count <= 4 })
    }

    @Test func toolIconsAreDistinct() {
        #expect(Set(Group.allCases.map(\.icon)).count == Group.allCases.count)
    }
}

/// Round 49, IC1: one icon per kind of tab, none repeated, and every symbol exists.
@Suite("Tab icons")
struct TabKindIconTests {
    @Test func noIconIsRepeatedExceptTheDatabaseSecurityEngines() {
        let kinds = WorkspaceTab.Kind.allCases.filter { ![.postgresSecurity, .mysqlSecurity, .mssqlMaintenance].contains($0) }
        let icons = kinds.map(\.icon)
        #expect(Set(icons).count == icons.count)
    }

    @Test func everyIconExists() {
        for kind in WorkspaceTab.Kind.allCases {
            #expect(NSImage(systemSymbolName: kind.icon, accessibilityDescription: nil) != nil, "\(kind.icon) for \(kind)")
        }
    }
}
