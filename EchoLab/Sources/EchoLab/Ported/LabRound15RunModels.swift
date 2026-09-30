import SwiftUI

/// Round 15: sizes of the mock windows on the Round 15 pages, in one place.
enum LabRound15Metrics {
    static let windowWidth: CGFloat = 540
    static let windowHeight: CGFloat = 300
    static let toolbarHeight: CGFloat = 38
    static let toolbarGlyph: CGFloat = 28
    static let tabHeight: CGFloat = 28
    static let footerHeight: CGFloat = 26
    static let columnWidth: CGFloat = 300
    static let columnHeight: CGFloat = 560
}

/// One simulated query, shared by the five Run concepts so they move together.
enum LabRunPhase: Equatable {
    case idle
    case running(started: Date)
    case succeeded(rows: Int, seconds: Double)
    case failed(line: Int)
    case cancelled

    var isRunning: Bool { if case .running = self { true } else { false } }
    var isResult: Bool {
        switch self {
        case .succeeded, .failed, .cancelled: true
        default: false
        }
    }
}

enum LabRunOutcome: String, CaseIterable, Identifiable {
    case success = "Succeeds"
    case failure = "Fails"
    var id: String { rawValue }
}

enum LabRunLength: String, CaseIterable, Identifiable {
    case quick = "1.5 s"
    case slow = "5 s"
    case manual = "Until I stop it"
    var id: String { rawValue }

    var seconds: Double? {
        switch self {
        case .quick: 1.5
        case .slow: 5
        case .manual: nil
        }
    }
}

@MainActor @Observable
final class LabRunSimulation {
    var phase: LabRunPhase = .idle
    var outcome: LabRunOutcome = .success
    var length: LabRunLength = .quick

    /// How long a result shows before the control returns to idle.
    static let resultHold: Double = 2.4

    @ObservationIgnored private var task: Task<Void, Never>?

    func toggle() {
        phase.isRunning ? cancel() : start()
    }

    func start() {
        task?.cancel()
        let started = Date()
        phase = .running(started: started)
        guard let seconds = length.seconds else { return }
        task = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard let self, !Task.isCancelled else { return }
            self.finish(outcome: self.outcome, started: started)
        }
    }

    func finish(outcome: LabRunOutcome, started: Date? = nil) {
        guard case .running(let runStart) = phase else { return }
        let elapsed = Date().timeIntervalSince(started ?? runStart)
        show(outcome == .success ? .succeeded(rows: 1_204, seconds: elapsed) : .failed(line: 3))
    }

    func cancel() {
        guard phase.isRunning else { return }
        show(.cancelled)
    }

    private func show(_ result: LabRunPhase) {
        task?.cancel()
        phase = result
        task = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.resultHold))
            guard let self, !Task.isCancelled, self.phase == result else { return }
            self.phase = .idle
        }
    }
}

/// The five Run ideas from the owner's review.
enum LabRunConcept: String, CaseIterable, Identifiable {
    case quietGlyph = "1 · Quiet glyph"
    case footer = "2 · In the footer"
    case editorCorner = "3 · On the editor card"
    case tab = "4 · In the tab"
    case onlyWhileRunning = "5 · Only while running"
    var id: String { rawValue }

    var summary: String {
        switch self {
        case .quietGlyph: "Run joins the editor capsule as a plain ▶ like its neighbours. While running it becomes ■ and the timer, in red; the result flashes as ✓ or ! and settles back. Right-click for the other modes."
        case .footer: "Run sits at the right of the editor's footer, where results appear. It becomes the timer and stop while running, then briefly shows rows and time before settling back. No Run in the toolbar."
        case .editorCorner: "A small ▶ floats in the editor card's top-right corner, showing on hover. Running, it grows into a capsule with a progress ring, the timer and stop."
        case .tab: "The active tab's icon becomes ▶ on hover. Running, the tab shows a spinner and the timer as its second line; hover it and the spinner becomes ■."
        case .onlyWhileRunning: "No permanent button: ⌘↩ or the gutter's ▸ start a run. A capsule rises at the bottom of the editor while it runs, turns into the result, then melts away."
        }
    }
}
