import SwiftUI

// Round 44: the choices for the blur under the footer. Never rename a case's raw value: the
// owner's picks are saved under it.

/// How the rows under the footer are softened. Each exhibit is one technique.
enum LabFBTechnique: String, CaseIterable {
    case echoToday = "Echo today"
    case stacked = "BT1 · Stacked blur steps"
    case maskedVariable = "BT3 · One variable blur (Core Image)"
    case material = "BT4 · The system's material"
    case fade = "BT5 · Fade to the card, no blur"
}

enum LabFBStrength: String, CaseIterable {
    case six = "BS0 · 6pt"
    case nine = "BS1 · 9pt"
    case twelve = "BS2 · 12pt (Echo today)"
    case sixteen = "BS3 · 16pt"
    case twenty = "BS4 · 20pt"

    var points: CGFloat {
        switch self {
        case .six: 6
        case .nine: 9
        case .twelve: 12
        case .sixteen: 16
        case .twenty: 20
        }
    }
}

/// How far above the card's bottom edge the blur reaches.
enum LabFBReach: String, CaseIterable {
    case footer = "BH0 · Only the footer (38pt)"
    case short = "BH1 · 16pt above the footer"
    case today = "BH2 · 24pt above the footer (Echo today)"
    case tall = "BH3 · 40pt above the footer"
    case taller = "BH4 · 64pt above the footer"

    var above: CGFloat {
        switch self {
        case .footer: 0
        case .short: SpacingTokens.md
        case .today: LayoutTokens.EdgeBlur.fade
        case .tall: SpacingTokens.xxl + SpacingTokens.xs
        case .taller: SpacingTokens.xxl * 2
        }
    }

    var points: CGFloat { LabFBLook.footerZone + above }
}

/// How the blur grows from nothing at the top of its reach to its strongest at the card's edge.
enum LabFBCurve: String, CaseIterable {
    case even = "CV0 · Even"
    case easeIn = "CV1 · Eases in (Echo today)"
    case easeInMore = "CV2 · Eases in more"
    case sCurve = "CV3 · S curve"
    case holdUnderPills = "CV4 · Full under the pills, easing above"
    case cubic = "CV5 · Very slow start (t³)"
    case exponential = "CV6 · Grows like the eye sees it (exponential)"

    var summary: String {
        switch self {
        case .even: "The same growth all the way down."
        case .easeIn: "Slow at the top, faster near the edge (strength × t^1.5)."
        case .easeInMore: "Hardly anything at the top, most of it near the edge (t²)."
        case .sCurve: "Eases in at the top and settles before the edge."
        case .holdUnderPills: "Full strength behind the footer, easing in above it: Echo before round 27."
        case .cubic: "Most of the height spent on the first point or two of blur, where text goes from sharp to soft."
        case .exponential: "The blur doubles every few points: the eye sees blur roughly by ratio, so this reads as an even fade."
        }
    }

    /// The share of the full blur at `t` (0 at the top of the reach, 1 at the card's edge).
    func amount(_ t: CGFloat, holdShare: CGFloat) -> CGFloat {
        let t = min(max(t, 0), 1)
        switch self {
        case .even: return t
        case .easeIn: return pow(t, 1.5)
        case .easeInMore: return t * t
        case .sCurve: return t * t * (3 - 2 * t)
        case .holdUnderPills:
            let top = max(1 - holdShare, 0.001)
            return t >= top ? 1 : pow(t / top, 1.5)
        case .cubic: return t * t * t
        case .exponential: return (exp(4.5 * t) - 1) / (exp(4.5) - 1)
        }
    }
}

enum LabFBTint: String, CaseIterable {
    case none = "TT0 · No tint"
    case light = "TT1 · 15% of the card's colour"
    case today = "TT2 · 35% (Echo today)"
    case strong = "TT3 · 50%"

    var opacity: Double {
        switch self {
        case .none: 0
        case .light: 0.15
        case .today: LayoutTokens.EdgeBlur.tintOpacity
        case .strong: 0.5
        }
    }
}

enum LabFBSteps: String, CaseIterable {
    case six = "ST0 · 6 steps"
    case ten = "ST1 · 10 steps (Echo today)"
    case sixteen = "ST2 · 16 steps"
    case twentyFour = "ST3 · 24 steps"

    var count: Int {
        switch self {
        case .six: 6
        case .ten: 10
        case .sixteen: 16
        case .twentyFour: 24
        }
    }
}

/// Playground only: whether the rows move under the blur.
enum LabFBMotion: String, CaseIterable {
    case scrolling = "Rows scrolling"
    case still = "Rows still"
}

/// Everything a specimen needs to draw one technique.
struct LabFBLook: Equatable {
    static let footerZone = LayoutTokens.Footer.height + LayoutTokens.Footer.bottomLift

    var technique: LabFBTechnique
    var strongest: CGFloat
    var reach: CGFloat
    var curve: LabFBCurve
    var tint: Double
    var steps: Int

    /// The share of the full blur at a height `y` above the card's edge.
    func amount(atHeight y: CGFloat) -> CGFloat {
        guard reach > 0 else { return 0 }
        return curve.amount(1 - y / reach, holdShare: Self.footerZone / reach)
    }
}
