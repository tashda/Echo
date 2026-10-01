import SwiftUI

/// Where the mark is in its life: before it appears, echoing in, resting, or leaving.
enum LabOCMarkPhase: Equatable {
    case hidden
    case playing(Date)
    case resting
    case leaving(Date)
}

/// The mark's pills, from echodb.dev's Mark.astro (viewBox 568 x 388, pills 400 x 112, corner 56,
/// offset 84 across and 138 down). `phase` drives them by the clock instead of by SwiftUI
/// animations, so the website's curve, cubic-bezier(0.3, 1.3, 0.5, 1), is followed exactly,
/// overshoot included. The timings are the ones in Mark.astro: 0.9 s per pill, 0.12 s apart.
struct LabOCMark: View {
    let phase: LabOCMarkPhase
    var ghosts = false
    var width: CGFloat = LayoutTokens.Welcome.markWidth
    var slow = false

    private static let viewWidth: CGFloat = 568
    private static let viewHeight: CGFloat = 388
    private static let travel: CGFloat = 110

    var body: some View {
        TimelineView(LabOCClock(phase: phase, slow: slow)) { context in
            marks(at: context.date)
        }
        .frame(width: width, height: width * Self.viewHeight / Self.viewWidth)
        .accessibilityHidden(true)
    }

    private func marks(at now: Date) -> some View {
        let unit = width / Self.viewWidth
        return ZStack(alignment: .topLeading) {
            ForEach(0..<3, id: \.self) { index in
                if ghosts {
                    ForEach([2, 1], id: \.self) { ghost in
                        pill(index, unit: unit, at: now, ghost: ghost)
                    }
                }
                pill(index, unit: unit, at: now, ghost: 0)
            }
        }
        .frame(width: width, height: width * Self.viewHeight / Self.viewWidth, alignment: .topLeading)
    }

    private func pill(_ index: Int, unit: CGFloat, at now: Date, ghost: Int) -> some View {
        let frame = LabOCPillFrame(phase: phase, index: index, ghost: ghost, at: now, slow: slow)
        return RoundedRectangle(cornerRadius: 56 * unit, style: .continuous)
            .fill(Self.gradient(index))
            .frame(width: 400 * unit, height: 112 * unit)
            .offset(x: (CGFloat(index) * 84 + frame.offset) * unit, y: CGFloat(index) * 138 * unit)
            .opacity(frame.opacity)
    }

    /// The three pill gradients of the brand mark.
    private static func gradient(_ index: Int) -> LinearGradient {
        let stops: [Gradient.Stop] = switch index {
        case 0: [.init(color: LabOCBrand.violet, location: 0), .init(color: LabOCBrand.indigo, location: 0.45),
                 .init(color: LabOCBrand.sky, location: 0.85), .init(color: LabOCBrand.cyan, location: 1)]
        case 1: [.init(color: LabOCBrand.lilac, location: 0), .init(color: LabOCBrand.orchid, location: 0.5),
                 .init(color: LabOCBrand.coral, location: 0.88), .init(color: LabOCBrand.peach, location: 1)]
        default: [.init(color: LabOCBrand.apricot, location: 0), .init(color: LabOCBrand.salmon, location: 0.5),
                  .init(color: LabOCBrand.pink, location: 0.88), .init(color: LabOCBrand.rose, location: 1)]
        }
        return LinearGradient(stops: stops, startPoint: UnitPoint(x: 0, y: 0), endPoint: UnitPoint(x: 1, y: 0.25))
    }
}

/// The mark's brand colours, copied from the artwork (Design/AppIcon/EchoIcon.svg).
private enum LabOCBrand {
    static let violet = Color(red: 0x8B / 255, green: 0x4B / 255, blue: 0xFF / 255)
    static let indigo = Color(red: 0x6F / 255, green: 0x6C / 255, blue: 0xFF / 255)
    static let sky = Color(red: 0x2A / 255, green: 0xA9 / 255, blue: 0xFF / 255)
    static let cyan = Color(red: 0x2A / 255, green: 0xCB / 255, blue: 0xFF / 255)
    static let lilac = Color(red: 0x91 / 255, green: 0x66 / 255, blue: 0xF0 / 255)
    static let orchid = Color(red: 0xA6 / 255, green: 0x60 / 255, blue: 0xD6 / 255)
    static let coral = Color(red: 0xFF / 255, green: 0x6E / 255, blue: 0x60 / 255)
    static let peach = Color(red: 0xFF / 255, green: 0x9B / 255, blue: 0x78 / 255)
    static let apricot = Color(red: 0xFF / 255, green: 0xA0 / 255, blue: 0x87 / 255)
    static let salmon = Color(red: 0xFF / 255, green: 0x7C / 255, blue: 0x8C / 255)
    static let pink = Color(red: 0xFF / 255, green: 0x5A / 255, blue: 0xA3 / 255)
    static let rose = Color(red: 0xFF / 255, green: 0x78 / 255, blue: 0xB8 / 255)
}

/// One pill's horizontal offset (in the artwork's units) and opacity at a moment.
struct LabOCPillFrame {
    var offset: CGFloat
    var opacity: Double

    init(phase: LabOCMarkPhase, index: Int, ghost: Int, at now: Date, slow: Bool) {
        let factor = slow ? 3.0 : 1.0
        switch phase {
        case .hidden:
            self.init(offset: -110, opacity: 0)
        case .resting:
            self.init(offset: 0, opacity: ghost == 0 ? 1 : 0)
        case .playing(let start):
            let elapsed = now.timeIntervalSince(start) / factor
            // A ghost trails its pill by 0.09 s per step.
            let local = (elapsed - Double(index) * LabOCTimings.pillStagger - Double(ghost) * LabOCTimings.ghostLag) / LabOCTimings.pillDuration
            let progress = min(max(local, 0), 1)
            let eased = LabOCBezier.value(progress, 0.3, 1.3, 0.5, 1)
            let weight = ghost == 0 ? 1 : (ghost == 2 ? 0.16 : 0.3)
            // Like the website, opacity follows the same curve (clamped); a ghost also fades as it arrives.
            self.init(offset: -110 * (1 - eased),
                      opacity: min(max(eased, 0), 1) * (ghost == 0 ? 1 : weight * (1 - progress)))
        case .leaving(let start):
            let elapsed = now.timeIntervalSince(start) / factor
            // Last pill first, quicker than coming in.
            let local = (elapsed - Double(2 - index) * LabOCTimings.leaveStagger) / LabOCTimings.leaveDuration
            let progress = min(max(local, 0), 1)
            let eased = LabOCBezier.value(progress, 0.5, 0, 0.9, 0.6)
            self.init(offset: -110 * eased, opacity: ghost == 0 ? 1 - eased : 0)
        }
    }

    private init(offset: CGFloat, opacity: Double) {
        self.offset = offset
        self.opacity = opacity
    }
}

/// Ticks every frame while the mark moves, then once more at rest.
struct LabOCClock: TimelineSchedule {
    let phase: LabOCMarkPhase
    let slow: Bool

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> [Date] {
        let start: Date
        let length: Double
        switch phase {
        case .playing(let date): (start, length) = (date, 1.6 * (slow ? 3 : 1))
        case .leaving(let date): (start, length) = (date, 0.8 * (slow ? 3 : 1))
        case .hidden, .resting: return [startDate]
        }
        let frames = (0...Int(length * 60)).map { start.addingTimeInterval(Double($0) / 60) }
        return [startDate] + frames.filter { $0 > startDate }
    }
}

/// CSS's `cubic-bezier(x1, y1, x2, y2)`: the curve's value at progress `x`.
enum LabOCBezier {
    static func value(_ x: Double, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
        guard x > 0, x < 1 else { return x <= 0 ? 0 : 1 }
        func axis(_ t: Double, _ a: Double, _ b: Double) -> Double {
            let u = 1 - t
            return 3 * u * u * t * a + 3 * u * t * t * b + t * t * t
        }
        // Solve for t by bisection: the x axis is monotonic for x1, x2 in 0...1.
        var low = 0.0
        var high = 1.0
        var t = x
        for _ in 0..<24 {
            t = (low + high) / 2
            if axis(t, x1, x2) < x { low = t } else { high = t }
        }
        return axis(t, y1, y2)
    }
}
