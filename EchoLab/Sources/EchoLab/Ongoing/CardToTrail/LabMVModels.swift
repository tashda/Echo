import SwiftUI

/// Round 54. A card is minimized: it leaves the tree and its item in the trail takes a dashed ring
/// (round 51's SH5). These are the ways it can get there, how the trail item answers, how the
/// gap in the tree closes, and how the card comes back.
enum LabMVMotion: String, CaseIterable {
    case inPlace = "AN0 · It fades where it is and the gap closes"
    case shrink = "AN1 · It shrinks straight into its trail item"
    case genie = "AN2 · A genie: squeezed sideways, then drawn into the item"
    case foldFly = "AN3 · It folds to its header, which becomes a disc and flies to the item"
    case slide = "AN4 · It slides left, under the trail"
    case arc = "AN5 · It becomes a disc and arcs to the item"
    case roll = "AN6 · It rolls up into its header, then dissolves into the item"
    case ringFirst = "AN7 · The item's ring draws itself while the card folds in place"

    var summary: String {
        switch self {
        case .inPlace: "No travel: the card fades and sinks 6%; the cards below rise. The quietest, and it does not say where the card went."
        case .shrink: "The card's frame scales and moves in a straight line to the item, corners rounding to a circle, the name crossfading to the letters."
        case .genie: "The card narrows to a sliver first, then drains downward into the item, like a window minimizing on macOS."
        case .foldFly: "The rows fold away, leaving the header; then the header becomes the item's disc and flies there. Two beats, so it is easy to follow."
        case .slide: "The card moves left the width of the rail and fades as it goes under the glass; the item answers. The least like a window and the most like a drawer."
        case .arc: "The card first shrinks to a disc in its own colour, which then travels along a curve to the item: a token being placed."
        case .roll: "The rows roll up into the header like a blind (rotating on their top edge), then the header shrinks and fades into the item."
        case .ringFirst: "The card folds in place and fades while the item's dashed ring draws itself round it. Nothing travels: the ring is the destination."
        }
    }

    /// Whether a token travels to the item (as opposed to the card changing where it is).
    var travels: Bool {
        switch self {
        case .shrink, .genie, .foldFly, .arc, .roll: true
        case .inPlace, .slide, .ringFirst: false
        }
    }

    var duration: Double {
        switch self {
        case .inPlace: 0.4
        case .shrink: 0.5
        case .genie: 0.65
        case .foldFly: 0.8
        case .slide: 0.45
        case .arc: 0.75
        case .roll: 0.75
        case .ringFirst: 0.6
        }
    }
}

/// How the trail item answers when the card arrives.
enum LabMVReceive: String, CaseIterable {
    case none = "RC0 · Nothing: the ring is there"
    case pop = "RC1 · It pops: a quick swell on a spring"
    case ring = "RC2 · The ring draws itself round the item"
    case glow = "RC3 · A soft glow of the server's colour, fading"
    case popRing = "RC4 · It pops and the ring draws itself"

    var summary: String {
        switch self {
        case .none: "The ring appears when the card lands."
        case .pop: "The item swells 28% and settles, 0.3 s."
        case .ring: "The dashed ring is drawn clockwise from the top over 0.5 s."
        case .glow: "A 10pt glow in the server's colour fades over 0.6 s."
        case .popRing: "Both: the swell on landing and the ring drawing as it settles."
        }
    }

    var pops: Bool { self == .pop || self == .popRing }
    var drawsRing: Bool { self == .ring || self == .popRing }
    var glows: Bool { self == .glow }
}

/// When the cards below move up.
enum LabMVGap: String, CaseIterable {
    case during = "GP0 · At once: the cards below rise as the card leaves"
    case after = "GP1 · After: they wait until the card has landed"

    var summary: String {
        switch self {
        case .during: "The list closes the moment the card starts to move, so nothing is left behind."
        case .after: "The space stays until the card lands, then the cards below glide up."
        }
    }
}

/// How the card comes back.
enum LabMVRestore: String, CaseIterable {
    case reverse = "RS0 · The same motion, backwards"
    case grow = "RS1 · It grows out of the item on a spring"
    case simple = "RS2 · It fades in where it was"

    var summary: String {
        switch self {
        case .reverse: "Whatever took the card in plays in reverse, so the motion is one you can learn."
        case .grow: "From the item to the card's place with a little overshoot: the item gives it back."
        case .simple: "The cards below make room, the card fades in. No travel."
        }
    }
}

enum LabMVSpeed: String, CaseIterable {
    case standard = "Standard"
    case fast = "Fast"
    case slow = "Slow (to study)"
    var scale: Double {
        switch self {
        case .standard: 1
        case .fast: 0.6
        case .slow: 2.2
        }
    }
}

struct LabMVLook {
    var motion: LabMVMotion
    var receive: LabMVReceive
    var gap: LabMVGap
    var restore: LabMVRestore
    var speed: LabMVSpeed

    static let today = LabMVLook(motion: .inPlace, receive: .none, gap: .after, restore: .simple, speed: .standard)

    @MainActor init(_ values: RoundValues) {
        motion = LabMVMotion(rawValue: values["motion"]) ?? .arc
        receive = LabMVReceive(rawValue: values["receive"]) ?? .popRing
        gap = LabMVGap(rawValue: values["gap"]) ?? .during
        restore = LabMVRestore(rawValue: values["restore"]) ?? .reverse
        speed = LabMVSpeed(rawValue: values["speed"]) ?? .standard
    }

    init(motion: LabMVMotion, receive: LabMVReceive, gap: LabMVGap, restore: LabMVRestore, speed: LabMVSpeed) {
        self.motion = motion
        self.receive = receive
        self.gap = gap
        self.restore = restore
        self.speed = speed
    }

    func with(motion: LabMVMotion) -> LabMVLook {
        var copy = self
        copy.motion = motion
        return copy
    }
}

/// A card on its way into the trail or out of it.
struct LabMVFlight: Equatable {
    let id: String
    let isReturn: Bool
    let start: Date
    let duration: Double
    let from: CGRect
    let to: CGRect
}

/// Where cards and trail items are, in the window's own coordinates.
struct LabMVFrames: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

enum LabMVEase {
    static func smooth(_ t: Double) -> Double { t * t * (3 - 2 * t) }
    static func out(_ t: Double) -> Double { 1 - pow(1 - t, 3) }
    /// A spring-like overshoot, ending at 1.
    static func overshoot(_ t: Double) -> Double {
        let c = 1.70158 * 1.2
        return 1 + (c + 1) * pow(t - 1, 3) + c * pow(t - 1, 2)
    }
    static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat { a + (b - a) * CGFloat(t) }
    static func clamp(_ t: Double) -> Double { min(max(t, 0), 1) }
    /// The part of `t` that falls between `lower` and `upper`, as 0 to 1.
    static func phase(_ t: Double, _ lower: Double, _ upper: Double) -> Double { clamp((t - lower) / (upper - lower)) }
}
