import SwiftUI

/// Round 46's choices: how the dock and the rows arrive when a server card opens, and how they
/// leave when it closes. The card's edge always glides on `expand` (round 30.2).
enum LabUFDock: String, CaseIterable {
    case atOnce = "DA0 · Appears at once (today)"
    case fade = "DA1 · Fades in with the edge"
    case grow = "DA2 · Grows out of the header"
    case slide = "DA3 · Slides down from under the name"
    case unfold = "DA4 · The capsule widens, then its icons appear"

    var summary: String {
        switch self {
        case .atOnce: "What Echo does now: the capsule is there the moment the edge starts moving."
        case .fade: "The capsule fades in over the edge's 0.22 s."
        case .grow: "The capsule scales up from 92% under the header, fading in and coming into focus, like glass taking shape."
        case .slide: "The capsule drops 10pt from under the name as it fades in, as if it were tucked behind the header."
        case .unfold: "An empty capsule widens from its middle, then the icons fade in one after another, left to right."
        }
    }
}

enum LabUFRows: String, CaseIterable {
    case atOnce = "RA0 · Appear at once (today)"
    case veil = "RA1 · Under the section switch's veil"
    case fadeAfter = "RA2 · Fade in once the edge has settled"
    case cascade = "RA3 · One after another, top first"
    case drawer = "RA4 · Uncovered by the edge, no fade"

    var summary: String {
        switch self {
        case .atOnce: "What Echo does now: every row is there before the edge has reached it."
        case .veil: "As switching sections: the rows are laid out under a veil in the card's colour while the edge moves, then the veil fades away (0.22 s)."
        case .fadeAfter: "The edge opens an empty card, then the rows fade in together."
        case .cascade: "Each row fades in and drops 4pt, 25 ms after the one above it, starting with the edge."
        case .drawer: "The rows are already in place and the moving edge uncovers them, like a drawer."
        }
    }
}

enum LabUFClose: String, CaseIterable {
    case atOnce = "CL0 · Dock and rows vanish, the edge glides (today)"
    case reverse = "CL1 · Opening, in reverse"
    case veilThenFold = "CL2 · The veil covers the rows, then the card folds"
    case quickFade = "CL3 · Dock and rows fade quickly, then the card folds"

    var summary: String {
        switch self {
        case .atOnce: "What Echo does now: the dock and the rows are gone the moment you click."
        case .reverse: "The rows and the dock leave the way the controls above bring them in, while the edge closes."
        case .veilThenFold: "As a section switch begins: the veil fades over the rows (0.12 s), then the edge closes and the dock goes back into the header."
        case .quickFade: "The dock and the rows fade in 0.1 s, then the empty card closes."
        }
    }
}

/// A playground knob: everything at a third of the speed, to see the choreography.
enum LabUFSpeed: String, CaseIterable {
    case normal = "Normal"
    case slow = "Slow motion (×3)"
}

struct LabUFLook {
    var dock: LabUFDock
    var rows: LabUFRows
    var close: LabUFClose
    var slow: Bool

    static let today = LabUFLook(dock: .atOnce, rows: .atOnce, close: .atOnce, slow: false)

    init(dock: LabUFDock, rows: LabUFRows, close: LabUFClose, slow: Bool) {
        self.dock = dock
        self.rows = rows
        self.close = close
        self.slow = slow
    }

    @MainActor init(_ values: RoundValues) {
        dock = LabUFDock(rawValue: values["dock"]) ?? .grow
        rows = LabUFRows(rawValue: values["rows"]) ?? .veil
        close = LabUFClose(rawValue: values["close"]) ?? .veilThenFold
        slow = values["speed"] == LabUFSpeed.slow.rawValue
    }

    @MainActor static func today(_ values: RoundValues) -> LabUFLook {
        var look = today
        look.slow = values["speed"] == LabUFSpeed.slow.rawValue
        return look
    }
}

/// The sections of the sample server's dock, each with its rows.
enum LabUFSection: Int, CaseIterable {
    case databases, security, objects, jobs, management

    var symbol: String {
        switch self {
        case .databases: "cylinder"
        case .security: "shield"
        case .objects: "square.grid.2x2"
        case .jobs: "clock"
        case .management: "gearshape"
        }
    }

    var title: String {
        switch self {
        case .databases: "Databases"
        case .security: "Security"
        case .objects: "Server Objects"
        case .jobs: "Agent Jobs"
        case .management: "Management"
        }
    }

    var rows: [(title: String, symbol: String)] {
        switch self {
        case .databases: ["AML", "ccsLDK10", "ccsLDK17", "ccsLDK20", "DBA", "ESB_INTEGRATION", "master"].map { ($0, "cylinder") }
        case .security: [("Security Overview", "lock.shield"), ("Logins", "person.2"), ("Server Roles", "person.3"), ("Credentials", "key")]
        case .objects: [("Linked Servers", "link"), ("Server Triggers", "bolt")]
        case .jobs: [("Agent Jobs Overview", "list.bullet.rectangle"), ("sp_purge_jobhistory", "clock"), ("CommandLog Cleanup", "clock"),
                     ("IndexOptimize", "clock"), ("DatabaseBackup - FULL", "clock")]
        case .management: [("Extended Events", "list.bullet.rectangle"), ("Database Mail", "envelope"), ("Activity Monitor", "gauge.high")]
        }
    }
}
