import SwiftUI

/// Round 55. Every server in the trail is connected; its card is open in the tree or minimized
/// (round 51's SH5). The dashed ring that marked a minimized server is out. These are other ways
/// to tell open from minimized, and whether the trail should also hold recent servers.
enum LabTSMark: String, CaseIterable {
    case ring = "ST0 · A dashed ring on a minimized server (the one you dislike)"
    case none = "ST1 · Nothing: the letters are the same either way"
    case dot = "ST2 · A dot beside an open server's item, as the Dock marks a running app"
    case bar = "ST3 · A short bar on the pill's edge beside an open server"
    case dim = "ST4 · A minimized server is dimmed to 55%"
    case disc = "ST5 · An open server rests on a soft disc of its colour"
    case badge = "ST6 · A small corner dot in the server's colour for an open server"
    case weight = "ST7 · Bold letters when open, regular when minimized"
    case line = "ST8 · A thin solid ring round an open server"
    case grey = "ST9 · A minimized server's letters turn grey; an open server's are in its colour"
    case chip = "ST10 · An open server sits on its own small glass chip"
    case under = "ST11 · A short line under an open server's letters"

    var summary: String {
        switch self {
        case .ring: "A 1.5pt dashed ring in the server colour on the minimized item."
        case .none: "The selection disc is the only marker. Open and minimized look the same."
        case .dot: "A 4pt dot in the pill's leading padding, level with the item. Familiar, and needs no change to the item itself."
        case .bar: "A 3pt by 14pt bar on the pill's leading edge; also moves with the selection disc."
        case .dim: "Minimized items are at 55%; open ones at full strength. The oldest way of saying inactive."
        case .disc: "A disc of the server's colour at 14% behind an open item; the white selection disc sits on top when it is the selected one."
        case .badge: "A 7pt dot in the item's top trailing corner, with a hairline of the pill's colour round it."
        case .weight: "Bold letters when open, regular at 85% when minimized. Costs no space, but is subtle."
        case .line: "A 1pt solid ring at 55% on an open item: the dashed ring's opposite, on the open one."
        case .grey: "The colour is the signal: open servers are coloured, minimized ones are grey and lose their colour until opened."
        case .chip: "A 30pt chip of glass behind an open item, over the pill's own glass."
        case .under: "A 2pt by 12pt line in the server's colour under the letters of an open item."
        }
    }
}

/// What the trail holds besides the connected servers.
enum LabTSRecents: String, CaseIterable {
    case none = "RT0 · Nothing: only connected servers (as it is)"
    case samePill = "RT1 · The last connected servers, dimmed, under a divider in the same pill"
    case twoPills = "RT2 · A second pill for recent servers, under the first"
    case button = "RT3 · A clock button at the pill's foot opens a list of recent servers"

    var summary: String {
        switch self {
        case .none: "Every item in the trail is a connected server. Reconnecting is the + (round 52's list)."
        case .samePill: "Connected servers on top; a hairline; the last servers you disconnected from, dimmed. Click one: it connects and glides up into the connected group."
        case .twoPills: "Two glass pills: connected servers, and below them the recent ones, each its own object. Click a recent: it connects and moves up into the first pill."
        case .button: "The trail stays pure; a clock button (like the + ) opens a popover of recent servers. Nothing is dimmed in the trail."
        }
    }
}

/// How a recent server looks in the trail.
enum LabTSRecentLook: String, CaseIterable {
    case dim = "RL0 · Dimmed to 38%"
    case grey = "RL1 · Grey letters"
    case clock = "RL2 · Dimmed, with a small clock in the corner"

    var summary: String {
        switch self {
        case .dim: "The letters in the server's colour at 38%: still recognisable by colour."
        case .grey: "The letters in secondary grey, no colour: clearly not part of the connected group."
        case .clock: "Dimmed, with a 9pt clock: says why it is faded."
        }
    }
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
    var mark = LabTSMark.disc
    var recents = LabTSRecents.samePill
    var recentLook = LabTSRecentLook.dim
    var count = LabTSCount.five

    static let today = LabTSLook(mark: .ring, recents: .none, recentLook: .dim, count: .five)

    @MainActor init(_ values: RoundValues) {
        mark = LabTSMark(rawValue: values["mark"]) ?? .disc
        recents = LabTSRecents(rawValue: values["recents"]) ?? .samePill
        recentLook = LabTSRecentLook(rawValue: values["recentLook"]) ?? .dim
        count = LabTSCount(rawValue: values["count"]) ?? .five
    }

    init(mark: LabTSMark, recents: LabTSRecents, recentLook: LabTSRecentLook, count: LabTSCount) {
        self.mark = mark; self.recents = recents; self.recentLook = recentLook; self.count = count
    }

    func with(mark: LabTSMark) -> LabTSLook {
        var copy = self
        copy.mark = mark
        return copy
    }
}

/// Where a server is in its life in the trail.
enum LabTSState {
    case open, minimized, recent, connecting
}
