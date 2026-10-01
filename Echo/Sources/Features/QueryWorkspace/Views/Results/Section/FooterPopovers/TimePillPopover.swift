import SwiftUI

/// The time pill's popover (round 41.5, PT0): where the time went (sending, waiting for the first
/// row, reading rows), when the run started and finished, and this tab's last runs; Run Again.
struct TimePillPopover: View {
    @Bindable var query: QueryEditorState

    private var report: QueryPerformanceTracker.Report? { query.livePerformanceReport ?? query.lastPerformanceReport }
    private var timeline: QueryRunTimeline? { report.flatMap { QueryRunTimeline(timings: $0.timings) } }

    private var title: String {
        if query.isExecuting { return "Running" }
        return query.lastRun.map { EchoFormatters.duration($0.duration) } ?? "Not run yet"
    }

    var body: some View {
        FooterPopoverContent(title: title, width: LayoutTokens.FloatingSurface.mediumWidth) {
            if let timeline {
                TimePillTimelineBar(timeline: timeline)
            }
            if let started = query.isExecuting ? query.runStartedAt : query.lastRun?.startedAt {
                FooterPopoverLine(label: "Started", value: started.formatted(date: .omitted, time: .standard))
            }
            if let finished = query.lastRun?.finishedAt {
                FooterPopoverLine(label: "Finished", value: finished.formatted(date: .omitted, time: .standard))
            }
            if let earlier = earlierRunsText {
                FooterPopoverLine(label: "Last runs", value: earlier)
            }
            if let rerun = query.rerunAction, !query.isExecuting {
                Divider()
                Button("Run Again", action: rerun).controlSize(.small)
            }
        }
    }

    /// The runs before the one on screen, newest first: "1.1 s · 1.4 s · 1.2 s".
    private var earlierRunsText: String? {
        let earlier = query.isExecuting ? query.runHistory : query.runHistory.dropLast()
        guard !earlier.isEmpty else { return nil }
        return earlier.reversed().map { EchoFormatters.duration($0.duration) }.joined(separator: " · ")
    }
}

/// The run as one bar in three colours, and what each colour is.
private struct TimePillTimelineBar: View {
    let timeline: QueryRunTimeline

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            GeometryReader { geometry in
                let shares = timeline.shares
                HStack(spacing: SpacingTokens.none) {
                    Rectangle().fill(ColorTokens.Text.tertiary).frame(width: geometry.size.width * shares.sending)
                    Rectangle().fill(ColorTokens.Status.warning).frame(width: geometry.size.width * shares.waiting)
                    Rectangle().fill(ColorTokens.accent).frame(width: geometry.size.width * shares.reading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ColorTokens.Sidebar.hoverFill)
                .clipShape(Capsule())
            }
            .frame(height: SpacingTokens.xs)
            HStack(spacing: SpacingTokens.sm) {
                legend("Sending \(EchoFormatters.duration(timeline.sending))", tint: ColorTokens.Text.tertiary)
                legend("Waiting \(EchoFormatters.duration(timeline.waiting))", tint: ColorTokens.Status.warning)
                legend("Rows \(EchoFormatters.duration(timeline.reading))", tint: ColorTokens.accent)
            }
            .font(TypographyTokens.detail)
        }
    }

    private func legend(_ text: String, tint: Color) -> some View {
        HStack(spacing: SpacingTokens.xxs) {
            Circle().fill(tint).frame(width: SpacingTokens.xxs2, height: SpacingTokens.xxs2)
            Text(text).foregroundStyle(ColorTokens.Text.secondary).monospacedDigit()
        }
    }
}
