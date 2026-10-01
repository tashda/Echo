import SwiftUI

/// Round 48's choices. Each enum starts with what Echo does today where there is one.

/// The welcome's mark. The owner asked for the name to go and the mark to echo in as on echodb.dev.
enum LabOCMarkStyle: String, CaseIterable {
    case withName = "WM0 · Mark and name, still (today)"
    case still = "WM1 · The mark alone, still"
    case echo = "WM2 · The mark alone, the pills echo in (echodb.dev)"
    case ghosts = "WM3 · The pills echo in with trailing ghosts"

    var summary: String {
        switch self {
        case .withName: "What Echo does now: the mark and the word Echo, there from the first frame."
        case .still: "The name is gone and nothing moves: the mark alone, 120pt wide."
        case .echo: "Exactly the website's hero: each pill slides in from 110 units to the left (a fifth of the mark's width) and fades in, 0.12 s apart, on a 0.9 s curve that overshoots a little before it settles."
        case .ghosts: "As WM2, and each pill drags two faint copies behind it that fade as they catch up: the echo made visible. A little busier; it ends on the same still mark."
        }
    }

    var showsName: Bool { self == .withName }
    var animates: Bool { self == .echo || self == .ghosts }
}

enum LabOCRest: String, CaseIterable {
    case atOnce = "WR0 · Buttons and recents are there from the start (today)"
    case rise = "WR1 · They rise in under the mark, one after the other"

    var summary: String {
        switch self {
        case .atOnce: "What Echo does now: the buttons and the recents sit there while the mark plays."
        case .rise: "The mark plays first. Then the three buttons rise 10pt into place and fade in, and the recents card follows 0.15 s later."
        }
    }
}

/// What the welcome does when a server connects.
enum LabOCLeave: String, CaseIterable {
    case pushed = "LV0 · It is pushed right as the columns slide in (today)"
    case stays = "LV1 · It stays where it is and fades away"
    case pillsOut = "LV2 · The pills echo out to the left, then the columns come in"

    var summary: String {
        switch self {
        case .pushed: "What Echo does now: the canvas shrinks to make room for the tree, and the welcome, centred in what is left, slides right while it cross-fades."
        case .stays: "The welcome holds its place in the window (the sliding is cancelled) and fades in 0.25 s, so nothing shoves it."
        case .pillsOut: "The echo in reverse: the pills leave to the left, last pill first, the buttons fade, and only then do the rail and tree come in. Costs 0.4 s before anything else happens."
        }
    }
}

/// How the connected server's page arrives.
enum LabOCArrive: String, CaseIterable {
    case atOnce = "AR0 · The page is there at once (today)"
    case fadeAfter = "AR1 · The page fades in once the columns have settled"
    case cascade = "AR2 · The page builds up: name, version, tools, databases"

    var summary: String {
        switch self {
        case .atOnce: "What Echo does now: the page is in its place as the columns start to move."
        case .fadeAfter: "The canvas is empty while the columns settle, then the page fades in together (0.25 s)."
        case .cascade: "Name, version, tools and the databases card each rise 8pt and fade in, 0.06 s apart, starting as the columns settle."
        }
    }
}

enum LabOCColumns: String, CaseIterable {
    case together = "CO0 · The rail's server and the tree arrive together (today)"
    case railFirst = "CO1 · The server appears in the rail, then the tree slides out"

    var summary: String {
        switch self {
        case .together: "What Echo does now: both move on the same spring."
        case .railFirst: "The new server grows into the rail first; the tree slides out from behind it 0.12 s later, so the click you made reads as the cause."
        }
    }
}

enum LabOCCloseWhere: String, CaseIterable {
    case welcome = "CW0 · The welcome page (today)"
    case serverPage = "CW1 · The page of the server the tab belonged to"

    var summary: String {
        switch self {
        case .welcome: "What Echo does now: closing the last tab clears the active server (AppDirector+TabDelegate: activeSessionID = nil), so the canvas shows the welcome while the server is still connected in the rail."
        case .serverPage: "The active server stays active, so the canvas shows its page. The welcome is for when nothing is connected."
        }
    }
}

enum LabOCCloseHow: String, CaseIterable {
    case crossfade = "CH0 · Cross-fade, the card scales to 98% (today)"
    case reveal = "CH1 · The page was underneath: the card lifts away and reveals it"
    case cascade = "CH2 · The card leaves, then the page builds up as when connecting"

    var summary: String {
        switch self {
        case .crossfade: "What Echo does now: the tab and the page swap on the house spring, 0.45 s, with a small scale."
        case .reveal: "The page is already in place under the card, so closing is only the card fading and settling away (0.28 s). As quick as opening a tab."
        case .cascade: "The card fades in 0.2 s, then the page builds up piece by piece, as in AR2. About 0.6 s per close."
        }
    }
}

/// A playground knob: everything at a third of the speed, to see the choreography.
enum LabOCSpeed: String, CaseIterable {
    case normal = "Normal"
    case slow = "Slow motion (×3)"
}

/// All the choices at once, read from the controls or fixed to what Echo does today.
struct LabOCLook: Equatable {
    var mark: LabOCMarkStyle
    var rest: LabOCRest
    var leave: LabOCLeave
    var arrive: LabOCArrive
    var columns: LabOCColumns
    var closeWhere: LabOCCloseWhere
    var closeHow: LabOCCloseHow
    var slow: Bool

    static let today = LabOCLook(mark: .withName, rest: .atOnce, leave: .pushed, arrive: .atOnce, columns: .together,
                                 closeWhere: .welcome, closeHow: .crossfade, slow: false)

    @MainActor init(_ values: RoundValues) {
        mark = LabOCMarkStyle(rawValue: values["mark"]) ?? .echo
        rest = LabOCRest(rawValue: values["rest"]) ?? .rise
        leave = LabOCLeave(rawValue: values["leave"]) ?? .stays
        arrive = LabOCArrive(rawValue: values["arrive"]) ?? .cascade
        columns = LabOCColumns(rawValue: values["columns"]) ?? .railFirst
        closeWhere = LabOCCloseWhere(rawValue: values["closeWhere"]) ?? .serverPage
        closeHow = LabOCCloseHow(rawValue: values["closeHow"]) ?? .reveal
        slow = values["speed"] == LabOCSpeed.slow.rawValue
    }

    init(mark: LabOCMarkStyle, rest: LabOCRest, leave: LabOCLeave, arrive: LabOCArrive, columns: LabOCColumns,
         closeWhere: LabOCCloseWhere, closeHow: LabOCCloseHow, slow: Bool) {
        self.mark = mark
        self.rest = rest
        self.leave = leave
        self.arrive = arrive
        self.columns = columns
        self.closeWhere = closeWhere
        self.closeHow = closeHow
        self.slow = slow
    }

    @MainActor static func today(_ values: RoundValues) -> LabOCLook {
        var look = today
        look.slow = values["speed"] == LabOCSpeed.slow.rawValue
        return look
    }
}

/// The moments of the story, in order.
enum LabOCStep: Int, CaseIterable {
    case launch, connect, openTab, closeTab

    var title: String {
        switch self {
        case .launch: "Launch"
        case .connect: "Connect"
        case .openTab: "Open a tab"
        case .closeTab: "Close the tab"
        }
    }

    var symbol: String {
        switch self {
        case .launch: "power"
        case .connect: "bolt"
        case .openTab: "plus.rectangle"
        case .closeTab: "xmark.rectangle"
        }
    }

    var caption: String {
        switch self {
        case .launch: "Echo opens"
        case .connect: "Connect to dkloosql10-p"
        case .openTab: "Open a query tab"
        case .closeTab: "Close the tab"
        }
    }
}
