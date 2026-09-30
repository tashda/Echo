import Observation
import SwiftUI

/// The run modes on Run's menu (right-click today), as in QueryRunMode.
enum LabRBMode: String, CaseIterable, Identifiable {
    case run = "Run"
    case statement = "Run Statement at Cursor"
    case explain = "Explain"
    case explainAnalyze = "Explain Analyze"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .run: "play.fill"
        case .statement: "text.line.first.and.arrowtriangle.forward"
        case .explain: "flowchart"
        case .explainAnalyze: "flowchart.fill"
        }
    }
}

/// One simulated query shared by every Run button on both round 20 pages, so they all move
/// together. Unlike round 15's simulation, a result stays in `phase` until the next run: each
/// button decides for itself how long to show it (the Hold control).
@MainActor @Observable
final class LabRBSimulation {
    enum Phase: Equatable {
        case idle
        case running(started: Date)
        case succeeded(rows: Int, seconds: Double)
        case failed(line: Int)
        case cancelled

        var isRunning: Bool { if case .running = self { true } else { false } }
    }

    static let shared = LabRBSimulation()

    private(set) var phase: Phase = .idle
    /// Counts runs, so a button can restart its result timer even when two results are equal.
    private(set) var runCount = 0
    /// The mode picked last from the menu (for L1).
    var lastMode: LabRBMode = .run
    var outcome: LabRunOutcome = .success
    var length: LabRBLength = .medium

    /// Several quick runs back to back, as when you press ⌘↩ over and over while editing.
    func runSeveral(count: Int = 3, seconds: Double = 0.3, gap: Double = 0.6) {
        sequence?.cancel()
        sequence = Task(name: "lab-run-button-sequence") { [weak self] in
            for _ in 0..<count {
                guard let self, !Task.isCancelled else { return }
                self.start(nil, seconds: seconds, outcome: .success)
                try? await Task.sleep(for: .seconds(seconds + gap))
            }
        }
    }

    /// Starts a long query and cancels it after a moment, as when you notice a mistake at once.
    func runAndCancelQuickly(after seconds: Double = 0.5) {
        start(nil, seconds: nil, outcome: .success)
        sequence?.cancel()
        sequence = Task(name: "lab-run-button-quick-cancel") { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard let self, !Task.isCancelled else { return }
            self.cancel()
        }
    }

    @ObservationIgnored private var runOutcome: LabRunOutcome = .success
    @ObservationIgnored private var sequence: Task<Void, Never>?
    @ObservationIgnored private var task: Task<Void, Never>?

    func toggle() { phase.isRunning ? cancel() : start() }

    func start(_ mode: LabRBMode? = nil) {
        start(mode, seconds: length.seconds, outcome: outcome)
    }

    /// A scenario: one run of a given length and outcome, whatever the knobs say.
    func start(_ mode: LabRBMode? = nil, seconds: Double?, outcome: LabRunOutcome) {
        if let mode { lastMode = mode }
        task?.cancel()
        let started = Date()
        runCount += 1
        runOutcome = outcome
        phase = .running(started: started)
        guard let seconds else { return }
        task = Task(name: "lab-run-button-simulation") { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard let self, !Task.isCancelled else { return }
            self.finish()
        }
    }

    func finish() {
        guard case .running(let started) = phase else { return }
        task?.cancel()
        let elapsed = Date().timeIntervalSince(started)
        phase = runOutcome == .success ? .succeeded(rows: 1_204, seconds: elapsed) : .failed(line: 3)
    }

    func cancel() {
        sequence?.cancel()
        guard phase.isRunning else { return }
        task?.cancel()
        phase = .cancelled
    }
}
