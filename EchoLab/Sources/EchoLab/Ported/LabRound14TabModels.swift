import SwiftUI

/// Round 14: the tab bar styles kept as Maybe on the design board (R9, N1R, N7).
enum LabRound14BarStyle: String, CaseIterable, Identifiable {
    case today = "R9 · Today"
    case sunk = "N1R · Tonal, sunk"
    case ink = "N7 · Ink active tab"

    var id: String { rawValue }

    var summary: String {
        switch self {
        case .today: "Round 9's strip as it is in Echo: the grey plate with the raised white gradient tab."
        case .sunk: "N1 refined: a track pressed slightly into the canvas, the active tab lifted a step lighter with a hairline edge, hairlines between inactive tabs. Nothing is white."
        case .ink: "A faint track; the active tab is filled in the text colour with its title reversed out."
        }
    }
}

/// Round 14: how a tool's pages open from the tab bar (ST1 is a Yes; the rest are Maybe).
enum LabRound14PageStyle: String, CaseIterable, Identifiable {
    case drawer = "ST1 · Drawer"
    case unfold = "ST2 · Tab unfolds"
    case group = "ST3 · Tab group"
    case menu = "ST5 · Page menu"
    case secondBar = "TT6 · Second bar"

    var id: String { rawValue }

    var summary: String {
        switch self {
        case .drawer: "A slim drawer slides out under the tool's tab with its pages; it folds away when you switch to another tab."
        case .unfold: "The tool's tab grows and shows its pages inside itself; the other tabs make room."
        case .group: "A coloured label followed by one real tab per page; click the label to collapse the group."
        case .menu: "The tab's title names the page, and its chevron opens a menu of pages with ⌘1 to ⌘6."
        case .secondBar: "A full-width second bar under the tab bar with the pages on the left and the tool's own controls on the right."
        }
    }
}

struct LabRound14Tab: Identifiable, Equatable {
    let id: String
    var title: String
    var database: String
    var symbol: String
    var pages: [String] = []
    var isRunning = false

    var hasPages: Bool { !pages.isEmpty }

    static let activityPages = ["Processes", "Waits", "I/O", "Queries", "XEvents", "Profiler"]

    static let samples: [LabRound14Tab] = [
        LabRound14Tab(id: "am", title: "Activity Monitor", database: "Test MSSQL", symbol: "waveform.path.ecg", pages: activityPages),
        LabRound14Tab(id: "jobs", title: "Jobs", database: "Test MSSQL", symbol: "clock"),
        LabRound14Tab(id: "q2", title: "Query 2", database: "AdventureWorks2022", symbol: "doc.text", isRunning: true),
        LabRound14Tab(id: "q3", title: "Query 3", database: "WideWorldImporters", symbol: "doc.text"),
    ]
}

/// Shared state of one mock window: which tab and page are active, and whether a group is open.
@Observable @MainActor
final class LabRound14TabState {
    var tabs = LabRound14Tab.samples
    var activeID = "am"
    var pageByTab: [String: String] = ["am": "Processes"]
    var isGroupOpen = true

    var activeTab: LabRound14Tab? { tabs.first { $0.id == activeID } }

    func page(of tab: LabRound14Tab) -> String { pageByTab[tab.id] ?? tab.pages.first ?? "" }

    func select(page: String, of tab: LabRound14Tab) {
        pageByTab[tab.id] = page
        activeID = tab.id
    }

    func addQuery() {
        let tab = LabRound14Tab(id: UUID().uuidString, title: "Query \(tabs.count + 1)", database: "AdventureWorks2022", symbol: "doc.text")
        tabs.append(tab)
        activeID = tab.id
    }

    func close(_ tab: LabRound14Tab) {
        guard tabs.count > 1, let index = tabs.firstIndex(of: tab) else { return }
        tabs.remove(at: index)
        if activeID == tab.id { activeID = tabs[min(index, tabs.count - 1)].id }
    }
}
