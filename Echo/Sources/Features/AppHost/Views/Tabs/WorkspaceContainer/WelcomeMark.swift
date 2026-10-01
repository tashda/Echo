import SwiftUI

/// Echo's mark (three pills, no tile) as the welcome shows it. The pills are driven by the clock
/// rather than by SwiftUI animations so the website's overshoot curve is followed exactly
/// (`WelcomeMarkMotion`).
struct WelcomeMark: View {
    let phase: WelcomeMarkPhase
    var width: CGFloat = LayoutTokens.Welcome.markWidth

    @Environment(\.echoMotion) private var motion

    var body: some View {
        TimelineView(WelcomeMarkClock(phase: phase, scale: motion.durationScale)) { context in
            pills(at: context.date)
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

/// Ticks every frame while the mark moves, then once at rest.
struct WelcomeMarkClock: TimelineSchedule {
    let phase: WelcomeMarkPhase
    let scale: Double

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> [Date] {
        let start: Date
        switch phase {
        case .playing(let date), .leaving(let date): start = date
        case .hidden, .resting: return [startDate]
        }
        guard let length = WelcomeMarkMotion.length(of: phase, scale: scale) else { return [startDate] }
        let frames = (0...Int(length * 60)).map { start.addingTimeInterval(Double($0) / 60) }
        return [startDate] + frames.filter { $0 > startDate }
    }
}
