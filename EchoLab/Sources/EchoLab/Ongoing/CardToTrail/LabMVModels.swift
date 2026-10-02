import SwiftUI

/// Round 54, revision 2. One animation, made properly, with the details that can be tuned. The card's
/// colour banner is what becomes the trail circle: the rows and the card's surface step aside, the
/// banner narrows into a disc of the server's colour as it travels, and the disc lands in the
/// item's place with a very small bounce, then hands over to the item (its letters and its dashed ring).
enum LabMVFold: String, CaseIterable {
    case direct = "FD0 · The card fades while the banner flies (AN1, smoothed)"
    case rows = "FD1 · The rows fold into the header first, overlapping the flight (AN3, smoothed)"
    case banner = "FD2 · The card's surface dissolves at once and only the banner travels"

    var summary: String {
        switch self {
        case .direct: "Everything fades together while the banner morphs and travels: the simplest, with no stage."
        case .rows: "The card shortens to its banner as it leaves, so you see the rows go in; the two moves overlap so there is no pause between fold and flight."
        case .banner: "The card disappears in the first quarter of the move and the banner is the only thing in flight: the cleanest shape, the least like a window closing."
        }
    }
}

enum LabMVPath: String, CaseIterable {
    case straight = "PH0 · A straight line"
    case curve = "PH1 · A gentle curve"
    case swoop = "PH2 · A swoop: out sideways, then in"

    var summary: String {
        switch self {
        case .straight: "The shortest way. It cuts across the cards between."
        case .curve: "A curve with a 25% bow: the disc leaves along the card and arrives from the side."
        case .swoop: "A curve with a 60% bow, as a token being placed."
        }
    }

    var bow: CGFloat {
        switch self {
        case .straight: 0
        case .curve: 0.25
        case .swoop: 0.6
        }
    }
}

/// The bounce when the disc reaches its place.
enum LabMVBounce: String, CaseIterable {
    case none = "BN0 · None: it settles"
    case tiny = "BN1 · Very little (about 3%)"
    case little = "BN2 · A little (about 6%)"
    case more = "BN3 · More (about 11%)"

    /// The spring's bounce, 0 to 1.
    var spring: Double {
        switch self {
        case .none: 0
        case .tiny: 0.14
        case .little: 0.24
        case .more: 0.38
        }
    }

    /// How much of the overshoot shows as the disc swelling.
    var swell: CGFloat {
        switch self {
        case .none: 0
        case .tiny: 0.8
        case .little: 0.9
        case .more: 1
        }
    }
}

enum LabMVDuration: String, CaseIterable {
    case fast = "DU0 · Fast (0.45 s)"
    case standard = "DU1 · Standard (0.6 s)"
    case slow = "DU2 · Slow (0.85 s)"

    var seconds: Double {
        switch self {
        case .fast: 0.45
        case .standard: 0.6
        case .slow: 0.85
        }
    }
}

/// The hand-over from the disc to the trail item.
enum LabMVLanding: String, CaseIterable {
    case ring = "LD0 · The disc becomes the item: its fill clears, the letters take its colour and the ring draws itself"
    case ringPop = "LD1 · As LD0, and the item swells once more as the ring closes"
    case disc = "LD2 · The disc fades into the item and the ring appears whole"

    var summary: String {
        switch self {
        case .ring: "The last 15% of the move: the fill fades, white letters become the server's colour, and the dashed ring is drawn clockwise from the top."
        case .ringPop: "The same, plus a 12% swell on the item after the ring closes."
        case .disc: "No drawing: the disc dissolves into the finished item."
        }
    }
}

/// When the cards below close the gap.
enum LabMVGap: String, CaseIterable {
    case during = "GP0 · At once: the cards below rise as the card leaves"
    case after = "GP1 · After: they wait until the card has landed"
}

/// How the card comes back.
enum LabMVRestore: String, CaseIterable {
    case reverse = "RS0 · The same motion, backwards"
    case simple = "RS1 · It fades in where it was"
}

enum LabMVSpeed: String, CaseIterable {
    case standard = "Standard"
    case slow = "Slow (3 times, to study)"
    var scale: Double { self == .slow ? 3 : 1 }
}

struct LabMVLook {
    var fold = LabMVFold.rows
    var path = LabMVPath.curve
    var bounce = LabMVBounce.tiny
    var duration = LabMVDuration.standard
    var landing = LabMVLanding.ring
    var gap = LabMVGap.during
    var restore = LabMVRestore.reverse
    var speed = LabMVSpeed.standard

    static let today = LabMVLook(fold: .direct, path: .straight, bounce: .none, duration: .fast, landing: .disc, gap: .after, restore: .simple, speed: .standard)

    @MainActor init(_ values: RoundValues) {
        fold = LabMVFold(rawValue: values["fold"]) ?? .rows
        path = LabMVPath(rawValue: values["path"]) ?? .curve
        bounce = LabMVBounce(rawValue: values["bounce"]) ?? .tiny
        duration = LabMVDuration(rawValue: values["duration"]) ?? .standard
        landing = LabMVLanding(rawValue: values["landing"]) ?? .ring
        gap = LabMVGap(rawValue: values["gap"]) ?? .during
        restore = LabMVRestore(rawValue: values["restore"]) ?? .reverse
        speed = LabMVSpeed(rawValue: values["speed"]) ?? .standard
    }

    init(fold: LabMVFold, path: LabMVPath, bounce: LabMVBounce, duration: LabMVDuration, landing: LabMVLanding,
         gap: LabMVGap, restore: LabMVRestore, speed: LabMVSpeed) {
        self.fold = fold; self.path = path; self.bounce = bounce; self.duration = duration
        self.landing = landing; self.gap = gap; self.restore = restore; self.speed = speed
    }

    /// The spring that drives the flight; the progress it animates overshoots 1 by the bounce.
    var animation: Animation {
        let seconds = duration.seconds * speed.scale
        return bounce == .none ? .smooth(duration: seconds) : .spring(duration: seconds, bounce: bounce.spring)
    }
}

/// A card on its way into the trail or out of it.
struct LabMVFlight: Equatable {
    let id: String
    let isReturn: Bool
    let from: CGRect
    let banner: CGRect
    let to: CGRect
}

/// Where cards, banners and trail items are, in the window's own coordinates.
struct LabMVFrames: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

enum LabMVEase {
    static func smooth(_ t: Double) -> Double { let c = clamp(t); return c * c * (3 - 2 * c) }
    static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat { a + (b - a) * CGFloat(t) }
    static func clamp(_ t: Double) -> Double { min(max(t, 0), 1) }
    /// The part of `t` between `lower` and `upper`, as 0 to 1.
    static func phase(_ t: Double, _ lower: Double, _ upper: Double) -> Double { clamp((t - lower) / (upper - lower)) }
}
