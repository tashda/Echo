import SwiftUI

// Round 20's choices. Names are stable: the owner's picks refer to them.

/// The button's shape at rest.
enum LabRBForm: String, CaseIterable {
    case plainGlyph = "F0 · Plain glyph (today)"
    case iconTitle = "F1 · Icon and Run"
    case titleShortcut = "F2 · Icon, Run and ⌘↩"
    case tintedGlass = "F3 · Tinted glass"
    case prominent = "F4 · Prominent glass"
    case disc = "F5 · Disc in the capsule"
    case circle = "F6 · Round glass button"

    var summary: String {
        switch self {
        case .plainGlyph: "A standard toolbar glyph in a capsule of its own, like its neighbours."
        case .iconTitle: "▶ and the word Run, like Xcode's older toolbar or SSMS's Execute."
        case .titleShortcut: "▶, Run and the shortcut in grey, so ⌘↩ is learned by looking."
        case .tintedGlass: "The capsule's glass takes a soft wash of the colour."
        case .prominent: "The system's prominent glass: a solid colour with a white glyph."
        case .disc: "A small solid disc inside the glass capsule, like a media player's play button."
        case .circle: "A round glass button of its own instead of a capsule."
        }
    }

    /// Forms whose glyph sits on a solid colour.
    var isFilled: Bool { self == .prominent || self == .disc }
}

enum LabRBIcon: String, CaseIterable {
    case playFill = "I1 · ▶ play.fill (today)"
    case play = "I2 · ▷ play (outline)"
    case playCircle = "I3 · play.circle.fill"
    case playSquare = "I4 · play.square.fill"
    case triangle = "I5 · arrowtriangle.forward.fill"
    case forward = "I6 · forward.fill"
    case bolt = "I7 · bolt.fill"
    case paperplane = "I8 · paperplane.fill"

    var symbol: String {
        switch self {
        case .playFill: "play.fill"
        case .play: "play"
        case .playCircle: "play.circle.fill"
        case .playSquare: "play.square.fill"
        case .triangle: "arrowtriangle.forward.fill"
        case .forward: "forward.fill"
        case .bolt: "bolt.fill"
        case .paperplane: "paperplane.fill"
        }
    }
}

enum LabRBColour: String, CaseIterable {
    case primary = "C0 · Label colour (today)"
    case secondary = "C1 · Quiet grey"
    case accent = "C2 · Accent"
    case green = "C3 · Green"
    case server = "C4 · The server's colour"

    var summary: String {
        switch self {
        case .primary: "Black in light mode, white in dark, like every toolbar glyph."
        case .secondary: "A step quieter than its neighbours."
        case .accent: "The system accent colour."
        case .green: "Green for go, as in SSMS and many database tools."
        case .server: "The connection's colour, so Run says where it runs (sample: orange)."
        }
    }

    var color: Color {
        switch self {
        case .primary: ColorTokens.Text.primary
        case .secondary: ColorTokens.Text.secondary
        case .accent: ColorTokens.accent
        case .green: ColorTokens.Status.success
        case .server: ColorTokens.Status.warning
        }
    }
}

/// What tells you Run will run only the selected text.
enum LabRBSelection: String, CaseIterable {
    case accentGlyph = "S0 · Accent colour (today)"
    case tooltipOnly = "S1 · Tooltip only"
    case dot = "S2 · A dot"
    case words = "S3 · Says Selection"

    var summary: String {
        switch self {
        case .accentGlyph: "▶ turns the accent colour."
        case .tooltipOnly: "Nothing changes; the tooltip says Run Selection."
        case .dot: "A small accent dot on the button's corner."
        case .words: "The word Selection appears beside ▶ (the capsule grows)."
        }
    }
}

enum LabRBHover: String, CaseIterable {
    case nothing = "H0 · Nothing (today)"
    case grow = "H1 · The glyph grows"
    case nudge = "H2 · The glyph nudges forward"
    case tint = "H3 · Tints to the accent"
    case reveal = "H4 · ⌘↩ slides out"

    var summary: String {
        switch self {
        case .nothing: "Like its neighbours: the system's press highlight only."
        case .grow: "As the section dock's icons do (round 19)."
        case .nudge: "▶ leans a couple of points forward, as if about to go."
        case .tint: "The glyph takes the accent colour while the pointer is on it."
        case .reveal: "The shortcut slides out beside ▶ (the capsule grows)."
        }
    }
}

/// When there is nothing to run (an empty editor) or nowhere to run it (not connected).
enum LabRBUnavailable: String, CaseIterable {
    case dimmed = "U0 · Dimmed (today)"
    case dimmedReason = "U1 · Dimmed, the tooltip says why"
    case hidden = "U2 · Hidden"
    case explains = "U3 · Stays on, a click says why"
}

/// Where the other run modes live.
enum LabRBMenu: String, CaseIterable {
    case rightClick = "M0 · Right-click (today)"
    case chevron = "M1 · A chevron beside ▶"
    case hold = "M2 · Click and hold"
    case hoverChevron = "M3 · Chevron on hover"

    var summary: String {
        switch self {
        case .rightClick: "Right-click Run, or the Query menu."
        case .chevron: "A split button: ▶ runs, the chevron opens the modes."
        case .hold: "Hold the button down for the modes, like Safari's Back button."
        case .hoverChevron: "The chevron appears only while the pointer is on Run."
        }
    }
}

enum LabRBMemory: String, CaseIterable {
    case alwaysRun = "L0 · Always Run (today)"
    case lastMode = "L1 · Becomes the last mode"

    var summary: String {
        switch self {
        case .alwaysRun: "A mode from the menu runs once; the button stays ▶."
        case .lastMode: "Like Xcode's Run, Test, Profile: after Explain, the button is Explain until you pick Run again."
        }
    }
}

/// How the button looks while the query runs.
enum LabRBRunning: String, CaseIterable {
    case redProminent = "R0 · Red capsule, ■ and timer (today)"
    case stopOnly = "R1 · ■ only, in red"
    case ring = "R2 · ■ in a spinning ring"
    case quietTimer = "R3 · ■ and timer, plain glass"
    case spinner = "R4 · Spinner, ■ on hover"
    case accentProminent = "R5 · Accent capsule, ■ and timer"
    case tintedGlass = "R6 · Red-tinted glass, ■ and timer"

    var summary: String {
        switch self {
        case .redProminent: "The system's prominent glass in red with ■ and the elapsed time."
        case .stopOnly: "The glyph becomes a red ■; the time is in the tooltip. Nothing widens."
        case .ring: "A red ■ inside a thin ring that spins. Nothing widens."
        case .quietTimer: "A red ■ and the time in the plain capsule."
        case .spinner: "A spinner, like the tab's icon; hover it and it becomes ■."
        case .accentProminent: "Prominent glass in the accent colour instead of red."
        case .tintedGlass: "A soft red wash of glass, between the plain and the solid capsule."
        }
    }

    /// Looks that show the elapsed time in the capsule.
    var showsTimer: Bool { [.redProminent, .quietTimer, .accentProminent, .tintedGlass].contains(self) }
}

enum LabRBStopIcon: String, CaseIterable {
    case stopFill = "X0 · ■ stop.fill (today)"
    case stopCircle = "X1 · stop.circle.fill"
    case stop = "X2 · □ stop (outline)"
    case xmark = "X3 · ✕ xmark"

    var symbol: String {
        switch self {
        case .stopFill: "stop.fill"
        case .stopCircle: "stop.circle.fill"
        case .stop: "stop"
        case .xmark: "xmark"
        }
    }
}

enum LabRBRunningMotion: String, CaseIterable {
    case still = "P0 · Still (today)"
    case breathe = "P1 · ■ breathes"
    case pulse = "P2 · ■ pulses"
    case shimmer = "P3 · Light sweeps across"
}

/// How the button changes into running and back.
enum LabRBChange: String, CaseIterable {
    case replace = "A0 · Swap in place (today)"
    case magic = "A1 · Magic replace"
    case morph = "A2 · Glass morph"
    case blur = "A3 · Blur through"
    case push = "A4 · Push forward"

    var summary: String {
        switch self {
        case .replace: "The contents change in place with the house spring; the symbol swaps."
        case .magic: "The symbol morphs its shared parts (SF Symbols' magic replace)."
        case .morph: "The glass stretches from one shape into the next (glassEffectID)."
        case .blur: "The old state blurs out as the new one blurs in."
        case .push: "▶ pushes out to the right and ■ comes in behind it."
        }
    }
}

/// What the button shows when a query ends.
enum LabRBResult: String, CaseIterable {
    case glyph = "E0 · ✓ or ! (today)"
    case drawn = "E1 · ✓ draws itself"
    case rows = "E2 · Rows and time"
    case flash = "E3 · The glass flashes"
    case nothing = "E4 · Nothing, straight back"

    var summary: String {
        switch self {
        case .glyph: "A green ✓ or red ! for a moment, then ▶."
        case .drawn: "The same, but the mark draws itself (SF Symbols 7's Draw On)."
        case .rows: "“1,204 rows · 1.5 s” or “Line 3” in the capsule (it grows)."
        case .flash: "▶ stays; the glass washes green or red and fades."
        case .nothing: "Straight back to ▶; the results and the line say how it went."
        }
    }
}

enum LabRBHold: String, CaseIterable {
    case short = "T0 · 1.2 s"
    case today = "T1 · 2.4 s (today)"
    case long = "T2 · 4 s"
    case errorsStay = "T3 · 2.4 s, errors stay until the next run"

    var seconds: Double {
        switch self {
        case .short: 1.2
        case .today, .errorsStay: 2.4
        case .long: 4
        }
    }
}

/// Playground: what the editor has, so the button's states can be tried.
enum LabRBEditorState: String, CaseIterable {
    case ready = "Ready"
    case selection = "Text selected"
    case empty = "Empty editor"
    case disconnected = "Not connected"

    var canRun: Bool { self == .ready || self == .selection }

    var reason: String {
        switch self {
        case .empty: "Type a query to run"
        case .disconnected: "Connect to a server to run"
        default: ""
        }
    }
}

/// When the running look appears, so a quick query never makes the button expand and snap back.
enum LabRBDelay: String, CaseIterable {
    case atOnce = "G0 · At once (today)"
    case afterQuarter = "G1 · After 0.3 s"
    case afterSecond = "G2 · After 1 s"
    case stopThenTimer2 = "G3 · ■ at once, timer after 2 s"
    case stopThenTimer5 = "G4 · ■ at once, timer after 5 s"

    var summary: String {
        switch self {
        case .atOnce: "The running look appears the moment you run, however short the query."
        case .afterQuarter: "▶ stays for the first 0.3 s; a quick query goes straight from ▶ to the result."
        case .afterSecond: "▶ stays for the first second; most interactive queries never show the running look."
        case .stopThenTimer2: "■ replaces ▶ at once (nothing widens), and the capsule grows for the timer only after 2 s."
        case .stopThenTimer5: "The same, but the timer waits 5 s, for queries that are really long."
        }
    }

    /// Seconds before ■ shows, and before the full running look (timer, prominent capsule) shows.
    var stopAfter: Double {
        switch self {
        case .atOnce, .stopThenTimer2, .stopThenTimer5: 0
        case .afterQuarter: 0.3
        case .afterSecond: 1
        }
    }

    var fullAfter: Double {
        switch self {
        case .atOnce: 0
        case .afterQuarter: 0.3
        case .afterSecond: 1
        case .stopThenTimer2: 2
        case .stopThenTimer5: 5
        }
    }
}

enum LabRBTimerFormat: String, CaseIterable {
    case clock = "K0 · 0:05 (today)"
    case seconds = "K1 · 5 s, then 1:05"
    case tenths = "K2 · 5.2 s, then 1:05"

    func text(_ elapsed: TimeInterval) -> String {
        let whole = Int(elapsed)
        switch self {
        case .clock:
            return String(format: "%d:%02d", whole / 60, whole % 60)
        case .seconds, .tenths:
            if whole >= 60 { return String(format: "%d:%02d", whole / 60, whole % 60) }
            return self == .seconds ? "\(whole) s" : "\(elapsed.formatted(.number.precision(.fractionLength(1)))) s"
        }
    }
}

/// Playground: how long the simulated query takes.
enum LabRBLength: String, CaseIterable {
    case instant = "0.2 s"
    case short = "0.8 s"
    case medium = "1.5 s"
    case slow = "4 s"
    case long = "12 s"
    case manual = "Until I stop it"

    var seconds: Double? {
        switch self {
        case .instant: 0.2
        case .short: 0.8
        case .medium: 1.5
        case .slow: 4
        case .long: 12
        case .manual: nil
        }
    }
}
