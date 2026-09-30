import SwiftUI

/// Sizes shared by round 20's Run buttons, taken from the toolbar specimen (RunSpecimenGlyph).
enum LabRBMetrics {
    /// A toolbar glyph's square, as macOS 26 lays out an icon-only toolbar item.
    static let glyph: CGFloat = 28
    /// The solid disc behind ▶ in F5.
    static let disc: CGFloat = 22
    /// The ring around ■ in R2.
    static let ring: CGFloat = 22
    static let ringWidth: CGFloat = 1.5
    static let dot: CGFloat = 6
    /// The system's text colour on a solid, selected control (white in both appearances).
    /// There is no token for it yet; the lab uses the system colour directly.
    static let onFill = Color(nsColor: .alternateSelectedControlTextColor)
}

/// One Run button drawn from a `LabRBLook`, driven by the shared simulation. Every choice on both
/// round 20 pages is drawn here, so Echo today, the proposal and the galleries stay comparable.
struct LabRBButton: View {
    let style: LabRBLook
    var editor: LabRBEditorState = .ready
    /// A still sample (the icon grid): always at rest, never runs.
    var isSample = false

    /// How far into a run the button is: 0 still ▶ (Delay), 1 ■ only, 2 the full running look.
    @State private var runStage = 2
    @State private var stageTask: Task<Void, Never>?
    @State var isHovered = false
    @State var shownResult: LabRBSimulation.Phase?
    @State private var holdTask: Task<Void, Never>?
    @State var noteCount = 0
    @State var showsNote = false
    @Namespace var glassSpace
    @Environment(\.echoMotion) var motion

    var simulation: LabRBSimulation { .shared }

    /// The look at this moment: before the Delay's timer is up, running is drawn as ■ only.
    var look: LabRBLook { runStage == 1 ? style.with(\.running, .stopOnly) : style }

    /// What the button is showing right now.
    enum Visual: Equatable {
        case rest
        case running(started: Date)
        case succeeded(rows: Int, seconds: Double)
        case failed(line: Int)

        var kind: Int {
            switch self {
            case .rest: 0
            case .running: 1
            case .succeeded: 2
            case .failed: 3
            }
        }
    }

    var visual: Visual {
        if isSample { return .rest }
        if case .running(let started) = simulation.phase {
            return runStage == 0 ? .rest : .running(started: started)
        }
        switch shownResult {
        case .succeeded(let rows, let seconds): return .succeeded(rows: rows, seconds: seconds)
        case .failed(let line): return .failed(line: line)
        default: return .rest
        }
    }

    var isRunning: Bool { if case .running = visual { true } else { false } }
    var canRun: Bool { editor.canRun }
    var hasSelection: Bool { editor == .selection }
    var isHidden: Bool { look.unavailable == .hidden && !canRun && !isRunning }
    var isDimmed: Bool { !canRun && !isRunning && (look.unavailable == .dimmed || look.unavailable == .dimmedReason) }

    var body: some View {
        Group {
            if isHidden {
                Color.clear.frame(width: SpacingTokens.none, height: LabRBMetrics.glyph)
            } else if case .running(let started) = visual, look.running.isProminent, look.change != .morph {
                nativeProminent(started: started)
                    .transition(transition)
            } else {
                shell
                    .transition(look.unavailable == .hidden ? .scale.combined(with: .opacity) : transition)
            }
        }
        .contextMenu { if !isSample { modeItems } }
        .help(helpText)
        .onHover { isHovered = $0 }
        .animation(motion.standard, value: visual)
        .animation(motion.standard, value: isHidden)
        .animation(motion.hover, value: isHovered)
        .animation(motion.hover, value: editor)
        .onChange(of: simulation.runCount) { _, _ in receive(simulation.phase) }
        .onChange(of: simulation.phase) { _, phase in receive(phase) }
    }

    /// The transition between two different views (a native prominent capsule and the shell).
    var transition: AnyTransition {
        switch look.change {
        case .blur: AnyTransition(.blurReplace)
        case .push: .push(from: .leading)
        default: .opacity
        }
    }

    var modeItems: some View {
        ForEach(LabRBMode.allCases) { mode in
            Button(mode.rawValue, systemImage: mode.symbol) { simulation.start(mode) }
                .disabled(!canRun)
        }
    }

    var helpText: String {
        if simulation.phase.isRunning && !isSample { return "Cancel (⌥⌘.)" }
        if !canRun {
            return look.unavailable == .dimmedReason || look.unavailable == .explains ? editor.reason : "Run (⌘↩)"
        }
        if look.memory == .lastMode, simulation.lastMode != .run { return simulation.lastMode.rawValue }
        return hasSelection ? "Run Selection (⌘↩)" : "Run (⌘↩)"
    }

    func primaryAction() {
        guard !isSample else { return }
        if simulation.phase.isRunning { return simulation.cancel() }
        guard canRun else {
            guard look.unavailable == .explains else { return }
            noteCount += 1
            showsNote = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(LabRBHold.today.seconds))
                showsNote = false
            }
            return
        }
        simulation.start(look.memory == .lastMode ? simulation.lastMode : nil)
    }

    /// Walks a run through the Delay's stages: ▶ for a moment, then ■, then the full look.
    private func stage(_ phase: LabRBSimulation.Phase) {
        stageTask?.cancel()
        guard phase.isRunning else { runStage = 2; return }
        let delay = style.delay
        runStage = delay.stopAfter > 0 ? 0 : (delay.fullAfter > 0 ? 1 : 2)
        guard runStage < 2 else { return }
        stageTask = Task { @MainActor in
            if delay.stopAfter > 0 {
                try? await Task.sleep(for: .seconds(delay.stopAfter))
                guard !Task.isCancelled else { return }
                runStage = delay.fullAfter > delay.stopAfter ? 1 : 2
            }
            let rest = delay.fullAfter - delay.stopAfter
            guard rest > 0 else { return }
            try? await Task.sleep(for: .seconds(rest))
            guard !Task.isCancelled else { return }
            runStage = 2
        }
    }

    /// Shows ✓ or ! for this button's own hold, or not at all.
    private func receive(_ phase: LabRBSimulation.Phase) {
        stage(phase)
        holdTask?.cancel()
        switch phase {
        case .succeeded, .failed:
            guard look.result != .none else { shownResult = nil; return }
            shownResult = phase
            if look.hold == .errorsStay, case .failed = phase { return }
            let seconds = look.hold.seconds
            holdTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(seconds))
                guard !Task.isCancelled else { return }
                shownResult = nil
            }
        default:
            shownResult = nil
        }
    }
}

extension LabRBRunning {
    /// Looks drawn as the system's prominent glass.
    var isProminent: Bool { self == .redProminent || self == .accentProminent }

    var fill: Color { self == .accentProminent ? ColorTokens.accent : ColorTokens.Status.error }
}
