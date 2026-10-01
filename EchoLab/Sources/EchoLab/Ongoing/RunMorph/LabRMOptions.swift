import SwiftUI

// Round 24's choices. Names are stable: the owner's picks refer to them. Never name a case `none`:
// `recommend: .none` would read as “no recommendation”.

/// How the icon itself turns ▶ into ■.
enum LabRMMorph: String, CaseIterable {
    case swap = "M0 · Swap (today)"
    case replace = "M1 · Replace in place (round 20's R1)"
    case corners = "M2 · Corners slide"
    case turn = "M3 · Turn and square"
    case magic = "M4 · Magic replace"
    case draw = "M5 · Draw off, draw on"
    case squeeze = "M6 · Squeeze through"

    var summary: String {
        switch self {
        case .swap: "The symbol is replaced as the whole button is swapped for the red one."
        case .replace: "The animation you liked in round 20's R1, R2 and R4: the same capsule stays, ▶ is replaced by ■ in place (SF Symbols' replace)."
        case .corners: "One shape: the triangle's tip splits into two corners that slide out until it is a square."
        case .turn: "The same, while the shape turns a quarter, so it reads as ▶ rolling into ■."
        case .magic: "SF Symbols' magic replace between play.fill and stop.fill."
        case .draw: "▶ erases itself and ■ draws in (SF Symbols 7's Draw Off and Draw On)."
        case .squeeze: "▶ shrinks to a point and ■ grows out of it."
        }
    }

    /// Morphs drawn as one custom shape rather than two symbols.
    var isShape: Bool { self == .corners || self == .turn }
}

/// How the capsule turns red.
enum LabRMFill: String, CaseIterable {
    case swap = "F0 · Swapped button (today)"
    case fade = "F1 · The glass fades to red"
    case flood = "F2 · Red floods out from ■"
    case plain = "F3 · No red capsule: a red ■ (round 20's R1)"

    var summary: String {
        switch self {
        case .swap: "The plain button is replaced by the system's red prominent button, which slides in beside it."
        case .fade: "The same glass capsule takes on the red while ▶ turns into ■."
        case .flood: "The red starts behind the glyph and spreads to the capsule's edges."
        case .plain: "The capsule stays plain glass, as in R1, R2 and R4; only ■ is red."
        }
    }
}

/// How the capsule grows and the timer appears.
enum LabRMGrow: String, CaseIterable {
    case swap = "W0 · With the swap (today)"
    case fadeAfter = "W1 · Grows, then the time fades in"
    case slideOut = "W2 · The time slides out from behind ■"
    case roll = "W3 · Grows, the digits roll in"
    case noTime = "W4 · No time in the capsule (round 20's R1)"

    var summary: String {
        switch self {
        case .swap: "The time arrives with the new button, all at once."
        case .fadeAfter: "The capsule's right edge moves out first; the time fades in once there is room."
        case .slideOut: "The time moves out from under ■ as the edge moves, as if it was there all along."
        case .roll: "The edge moves out and the digits roll up into place, as numbers do in Control Center."
        case .noTime: "Nothing widens, ever: the time is in the tooltip and the footer, as in R1, R2 and R4."
        }
    }
}

/// The timing of the whole change.
enum LabRMCurve: String, CaseIterable {
    case spring = "K0 · House spring (today)"
    case smooth = "K1 · Smooth, no overshoot"
    case staged = "K2 · Staged: icon, then width"

    var summary: String {
        switch self {
        case .spring: "0.45 s with a little bounce, everything together."
        case .smooth: "0.35 s ease, no bounce: the edge settles instead of wobbling."
        case .staged: "▶ turns into ■ and goes red first (0.25 s); the capsule grows for the time just after."
        }
    }
}

/// How it goes back when the query ends (the ✓ that draws itself is decided, E1).
enum LabRMEnding: String, CaseIterable {
    case together = "B0 · Shrinks while the ✓ draws"
    case shrinkFirst = "B1 · Shrinks, then the ✓ draws"
    case reverse = "B2 · ■ turns back into ▶, no ✓"

    var summary: String {
        switch self {
        case .together: "The time fades, the red drains and the capsule shrinks as the ✓ draws itself."
        case .shrinkFirst: "The capsule is back to its size and colour first; then the ✓ draws in the plain glass."
        case .reverse: "The morph runs backwards. You decided on a ✓ (E1), so this is only for comparison."
        }
    }
}
