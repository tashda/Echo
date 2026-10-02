import SwiftUI

/// Round 55, revision 2. The owner's rules: connected servers keep today's look and the white
/// selection disc; nothing is dimmed or greyed that is connected, and nothing is added to it. So a
/// minimized server has no mark: it drops below a hairline in the connected pill. Recent servers
/// (disconnected, so dimmed) are a pill of their own. Connecting to a server that is in neither gets
/// its own button, and not a +.
enum LabTSDivider: String, CaseIterable {
    case line = "DV0 · A short hairline"
    case full = "DV1 · A hairline across the pill"
    case gap = "DV2 · Space only, no line"

    var summary: String {
        switch self {
        case .line: "A 1pt line 60% of an item wide, centred: the quietest line that still reads as a boundary."
        case .full: "A 1pt line across the pill's inner width."
        case .gap: "Eight points of space between the groups and nothing drawn."
        }
    }
}

/// The glyph of the connect button.
enum LabTSConnectIcon: String, CaseIterable {
    case plus = "CI0 · + (Echo today)"
    case rack = "CI1 · A server rack"
    case bolt = "CI2 · A bolt (Quick Connect)"
    case link = "CI3 · A link"
    case search = "CI4 · A magnifying glass: find a connection"
    case plug = "CI5 · A power plug"
    case network = "CI6 · A network"
    case cable = "CI7 · A cable connector"

    var symbol: String {
        switch self {
        case .plus: "plus"
        case .rack: "server.rack"
        case .bolt: "bolt.fill"
        case .link: "link"
        case .search: "magnifyingglass"
        case .plug: "powerplug"
        case .network: "network"
        case .cable: "cable.connector"
        }
    }

    var summary: String {
        switch self {
        case .plus: "Says add something new, which is not what connecting to a saved server is."
        case .rack: "What a server looks like: says server, not the action."
        case .bolt: "Fast: matches Quick Connect, one of the three actions behind it."
        case .link: "Connect, in the sense of a link; also reads as a URL."
        case .search: "The list behind it is searchable and starts with a search field; says find, not connect."
        case .plug: "Connecting in the most literal way."
        case .network: "A graph of nodes: connections between things."
        case .cable: "The connector itself, at the size of a toolbar glyph."
        }
    }
}

/// What the connect button sits on.
enum LabTSConnectForm: String, CaseIterable {
    case circle = "FM0 · Its own glass circle under the recents"
    case inPill = "FM1 · The last item of the bottom pill"
    case bare = "FM2 · The glyph alone under the pills, no glass"

    var summary: String {
        switch self {
        case .circle: "A third glass object: connected, recent, and a button to reach any other server."
        case .inPill: "As the + is today, at the foot of the last pill."
        case .bare: "No container: the glyph in the secondary colour, like a toolbar button on the canvas."
        }
    }
}

/// How a recent (disconnected) server is drawn.
enum LabTSRecentLook: String, CaseIterable {
    case dim38 = "RL0 · Its colour at 38%"
    case dim50 = "RL1 · Its colour at 50%"
    case grey = "RL2 · Grey letters"
}

enum LabTSCount: String, CaseIterable {
    case three = "Three"
    case five = "Five"
    case eight = "Eight"

    var count: Int {
        switch self {
        case .three: 3
        case .five: 5
        case .eight: 8
        }
    }
}

struct LabTSLook {
    var divider = LabTSDivider.line
    var icon = LabTSConnectIcon.rack
    var form = LabTSConnectForm.circle
    var recent = LabTSRecentLook.dim38
    var count = LabTSCount.five
    /// Today's trail: one pill, a dashed ring on a minimized server, a + inside it, no recents.
    var isToday = false

    static let today = LabTSLook(isToday: true)

    @MainActor init(_ values: RoundValues) {
        divider = LabTSDivider(rawValue: values["divider"]) ?? .line
        icon = LabTSConnectIcon(rawValue: values["icon"]) ?? .rack
        form = LabTSConnectForm(rawValue: values["form"]) ?? .circle
        recent = LabTSRecentLook(rawValue: values["recent"]) ?? .dim38
        count = LabTSCount(rawValue: values["count"]) ?? .five
    }

    init(isToday: Bool) {
        self.isToday = isToday
        if isToday { icon = .plus; form = .inPill }
    }
}
