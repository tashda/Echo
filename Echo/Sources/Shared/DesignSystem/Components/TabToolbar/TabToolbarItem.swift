import SwiftUI

/// A button a tab puts in the window toolbar (round 37.5). It is data, so the toolbar can draw
/// every tab's buttons the same way: the tab's symbol, its special button, then its group.
///
/// The action must read what it acts on when it runs (the selected job, the open sheet's state),
/// not capture it: an item is only replaced when its title, symbol or state change.
struct TabToolbarItem: Identifiable, Sendable, Equatable {
    let id: String
    var title: String
    var symbol: String
    var isDisabled = false
    /// A toggle that is on (Statistics, Watch Live Data): the symbol in the accent colour.
    var isOn = false
    /// A switch (DISTINCT, Watch Live Data): drawn as a toolbar toggle so on and off show natively.
    var isToggle = false
    /// A spinner in place of the symbol (Refresh while reloading).
    var isBusy = false
    /// What it started is running: a special button turns into `runningTitle` with a pulsing dot.
    var isRunning = false
    var runningTitle: String?
    /// A button that opens a menu of these instead of acting (Export ▾, Add ▾).
    var menu: [TabToolbarItem] = []
    var action: @MainActor @Sendable () -> Void = {}

    static func == (lhs: TabToolbarItem, rhs: TabToolbarItem) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.symbol == rhs.symbol && lhs.isDisabled == rhs.isDisabled
            && lhs.isOn == rhs.isOn && lhs.isToggle == rhs.isToggle && lhs.isBusy == rhs.isBusy && lhs.isRunning == rhs.isRunning
            && lhs.runningTitle == rhs.runningTitle && lhs.menu == rhs.menu
    }

    /// Refresh, with a spinner while the tab reloads.
    static func refresh(isBusy: Bool = false, title: String = "Refresh", action: @escaping @MainActor @Sendable () -> Void) -> TabToolbarItem {
        TabToolbarItem(id: "refresh", title: title, symbol: "arrow.clockwise", isDisabled: isBusy, isBusy: isBusy, action: action)
    }
}

/// What a tab shows in the window toolbar: its special button (what you start or make here) and
/// its other buttons in groups (round 37.5: GR1, one capsule split by hairlines).
struct TabToolbarSection: Sendable, Equatable {
    var special: TabToolbarItem?
    var groups: [[TabToolbarItem]] = []

    var isEmpty: Bool { special == nil && groups.allSatisfy(\.isEmpty) }
}

struct TabToolbarSectionKey: PreferenceKey {
    static var defaultValue: TabToolbarSection? { nil }

    static func reduce(value: inout TabToolbarSection?, nextValue: () -> TabToolbarSection?) {
        if value == nil { value = nextValue() }
    }
}

extension View {
    /// The tab's buttons for the window toolbar (round 37.5). The innermost view that sets them
    /// wins, so a page can replace its tool's. Pickers and search stay on the header line.
    func tabToolbar(special: TabToolbarItem? = nil, groups: [[TabToolbarItem]] = []) -> some View {
        let section = TabToolbarSection(special: special, groups: groups.filter { !$0.isEmpty })
        return transformPreference(TabToolbarSectionKey.self) { value in
            if value == nil { value = section }
        }
    }
}
