#if DEBUG
import AppKit
import QuartzCore

/// How smoothly the window drew during each automation step: a display link on the workspace window logs the gap between
/// frames, and each step ends with one line: `automation-frames <label> frames=N fps=F p50=ms p95=ms max=ms hitches=N lostMs=T`.
/// A frame is a hitch when it comes later than 1.5 refresh periods (a frame was skipped); `lostMs` is the time over the refresh
/// period summed over all frames; `jank` counts frames later than 25 ms (under 40 fps), whatever the display's rate. While the main thread is busy the link's callbacks wait for it, so a long layout shows as a long gap.
@MainActor
final class AutomationFrameMeter: NSObject {
    static let shared = AutomationFrameMeter()

    private var link: CADisplayLink?
    private weak var linkedWindow: NSWindow?
    private var lastTimestamp: CFTimeInterval = 0
    private var gaps: [Double] = []
    private var label = ""
    private var periodMs = 1000.0 / 60
    private var cpuAtStart = AutomationFrameMeter.mainThreadCPUMilliseconds()

    /// CPU time the main thread has used so far. Unlike the frame gaps it does not grow when other programs
    /// take the machine, so two runs can be compared on it.
    private static func mainThreadCPUMilliseconds() -> Double {
        var spec = timespec()
        clock_gettime(CLOCK_THREAD_CPUTIME_ID, &spec)
        return Double(spec.tv_sec) * 1000 + Double(spec.tv_nsec) / 1_000_000
    }

    /// Ends the running step (printing its frames) and begins a new one.
    func begin(step label: String) {
        attachIfNeeded()
        flush()
        self.label = label
        cpuAtStart = Self.mainThreadCPUMilliseconds()
        lastTimestamp = 0
    }

    private func attachIfNeeded() {
        guard let window = NSApp.windows.first(where: { $0.identifier == AppWindowIdentifier.workspace }), window !== linkedWindow,
              let view = window.contentView else { return }
        link?.invalidate()
        let newLink = view.displayLink(target: self, selector: #selector(tick(_:)))
        newLink.add(to: .main, forMode: .common)
        link = newLink
        linkedWindow = window
        let hertz = window.screen?.maximumFramesPerSecond ?? 60
        periodMs = 1000.0 / Double(max(hertz, 1))
        print("automation-frames-meter refresh \(hertz) Hz, window minSize \(window.minSize) contentMinSize \(window.contentMinSize) maxSize \(window.maxSize) frame \(window.frame)"); fflush(stdout)
    }

    @objc private func tick(_ link: CADisplayLink) {
        if lastTimestamp > 0 { gaps.append((link.timestamp - lastTimestamp) * 1000) }
        lastTimestamp = link.timestamp
    }

    func flush() {
        defer { gaps = [] }
        let cpu = Self.mainThreadCPUMilliseconds() - cpuAtStart
        guard !label.isEmpty, !gaps.isEmpty else {
            if !label.isEmpty { print("automation-frames \(label) frames=0"); fflush(stdout) }
            return
        }
        let sorted = gaps.sorted()
        func percentile(_ p: Double) -> Double { sorted[min(Int(Double(sorted.count) * p), sorted.count - 1)] }
        let total = gaps.reduce(0, +)
        let hitches = gaps.filter { $0 > periodMs * 1.5 }.count
        let lost = gaps.reduce(0) { $0 + max($1 - periodMs, 0) }
        let janks = gaps.filter { $0 > 25 }.count
        print(String(format: "automation-frames %@ frames=%d fps=%.0f p50=%.1f p95=%.1f max=%.1f hitches=%d lostMs=%.0f jank=%d cpuMs=%.0f",
                     label, gaps.count, Double(gaps.count) / max(total / 1000, 0.001), percentile(0.5), percentile(0.95), sorted.last ?? 0, hitches, lost, janks, cpu))
        fflush(stdout)
    }
}
#endif
