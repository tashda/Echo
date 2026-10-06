import SwiftUI

/// Echo's mark (three pills, no tile) as the welcome shows it. The pills are driven by the clock
/// rather than by SwiftUI animations so the website's overshoot curve is followed exactly
/// (`WelcomeMarkMotion`).
struct WelcomeMark: View {
    let phase: WelcomeMarkPhase
    var width: CGFloat = LayoutTokens.Welcome.markWidth

    @Environment(\.echoMotion) private var motion

    var body: some View {
        Group {
            // Only a moving mark needs a clock. One that has settled is drawn once: its clock used to be asked for
            // "one more entry" for ever, which kept the whole window redrawing 60 times a second (13% of the main
            // thread while the welcome sat there, traced 2026-10-06).
            if WelcomeMarkClock(phase: phase, scale: motion.durationScale).isMoving(at: Date()) {
                TimelineView(WelcomeMarkClock(phase: phase, scale: motion.durationScale)) { context in
                    pills(at: context.date)
                }
            } else {
                pills(at: Date())
            }
        }
        .frame(width: width, height: width * WelcomeMarkMotion.viewHeight / WelcomeMarkMotion.viewWidth)
        .accessibilityHidden(true)
    }

    private func pills(at now: Date) -> some View {
        let unit = width / WelcomeMarkMotion.viewWidth
        return ZStack(alignment: .topLeading) {
            ForEach(0..<3, id: \.self) { index in
                let frame = WelcomeMarkMotion.pillFrame(phase: phase, index: index, at: now, scale: motion.durationScale)
                RoundedRectangle(cornerRadius: 56 * unit, style: .continuous)
                    .fill(ColorTokens.Brand.markPillGradient(index))
                    .frame(width: 400 * unit, height: 112 * unit)
                    .offset(x: (CGFloat(index) * 84 + frame.offset) * unit, y: CGFloat(index) * 138 * unit)
                    .opacity(frame.opacity)
            }
        }
        .frame(width: width, height: width * WelcomeMarkMotion.viewHeight / WelcomeMarkMotion.viewWidth, alignment: .topLeading)
    }
}

/// Ticks every frame while the mark moves, then not at all.
struct WelcomeMarkClock: TimelineSchedule {
    let phase: WelcomeMarkPhase
    let scale: Double

    /// When the mark's motion started and ends; nil for a mark at rest or not yet shown.
    private var motion: (start: Date, end: Date)? {
        let start: Date
        switch phase {
        case .playing(let date), .leaving(let date): start = date
        case .hidden, .resting: return nil
        }
        guard let length = WelcomeMarkMotion.length(of: phase, scale: scale) else { return nil }
        return (start, start.addingTimeInterval(length))
    }

    func isMoving(at date: Date) -> Bool {
        guard let motion else { return false }
        return date < motion.end
    }

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> [Date] {
        guard let motion, startDate < motion.end else { return [] }
        let frames = (0...Int(motion.end.timeIntervalSince(motion.start) * 60)).map { motion.start.addingTimeInterval(Double($0) / 60) }
        return [startDate] + frames.filter { $0 > startDate }
    }
}
