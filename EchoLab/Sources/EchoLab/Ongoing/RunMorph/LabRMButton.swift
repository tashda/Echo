import SwiftUI

/// Everything one round 24 button is drawn with.
struct LabRMOptions: Equatable {
    var morph: LabRMMorph = .swap
    var fill: LabRMFill = .swap
    var grow: LabRMGrow = .swap
    var curve: LabRMCurve = .spring
    var ending: LabRMEnding = .together

    /// Run as Echo draws it after round 20: the plain button swapped for the red prominent one.
    static let today = LabRMOptions()

    @MainActor init(values: RoundValues) {
        morph = LabRMMorph(rawValue: values["morph"]) ?? .replace
        fill = LabRMFill(rawValue: values["fill"]) ?? .fade
        grow = LabRMGrow(rawValue: values["grow"]) ?? .fadeAfter
        curve = LabRMCurve(rawValue: values["curve"]) ?? .staged
        ending = LabRMEnding(rawValue: values["ending"]) ?? .together
    }

    init() {}

    func with<Value>(_ path: WritableKeyPath<LabRMOptions, Value>, _ value: Value) -> LabRMOptions {
        var copy = self
        copy[keyPath: path] = value
        return copy
    }
}

/// Run from ▶ to ■ and the timer, and back to ✓, as the options say. Driven by round 20's shared
/// simulated query, so every exhibit runs together.
struct LabRMButton: View {
    let options: LabRMOptions

    /// 0 at rest, 1 red with ■, 2 grown with the time. Runs through 1 only for the staged curve.
    @State private var stage = 0
    @State private var result: LabRBSimulation.Phase?
    /// B1: the ✓ waits until the capsule is back to its size.
    @State private var showsMark = true
    @State private var task: Task<Void, Never>?
    @Environment(\.echoMotion) private var motion

    private var simulation: LabRBSimulation { .shared }
    private var isRunning: Bool { simulation.phase.isRunning }

    var body: some View {
        Group {
            if options.fill == .swap { swapped } else { oneCapsule }
        }
        .animation(curve, value: stage)
        .animation(curve, value: result)
        .animation(curve, value: showsMark)
        .onChange(of: simulation.runCount) { _, _ in advance(simulation.phase) }
        .onChange(of: simulation.phase) { _, phase in advance(phase) }
        .help(isRunning ? "Stop (⌘↩)" : "Run in employees on Prod SQL (⌘↩)")
    }

    // MARK: F0: two buttons, as Echo does today

    @ViewBuilder
    private var swapped: some View {
        if stage > 0, case .running(let started) = simulation.phase {
            Button { simulation.cancel() } label: {
                Label {
                    LabRMTimer(started: started, rolls: options.grow == .roll)
                } icon: {
                    LabRMGlyph(morph: options.morph, isStop: true, colour: LabRBMetrics.onFill)
                        .frame(width: LabRMMetrics.glyphWidth)
                }
            }
            .labelStyle(.titleAndIcon)
            .buttonStyle(.glassProminent)
            .tint(ColorTokens.Status.error)
        } else {
            RunSpecimenCapsule {
                Button { simulation.toggle() } label: { restMark }
                    .buttonStyle(.plain)
            }
        }
    }

    // MARK: F1, F2: one capsule that changes

    private var oneCapsule: some View {
        Button { simulation.toggle() } label: {
            HStack(spacing: SpacingTokens.none) {
                restMark.zIndex(1)
                if stage >= 2, options.grow != .noTime, case .running(let started) = simulation.phase {
                    LabRMTimer(started: started, rolls: options.grow == .roll)
                        .foregroundStyle(options.fill == .plain ? ColorTokens.Text.primary : LabRBMetrics.onFill)
                        .padding(.trailing, SpacingTokens.xs)
                        .transition(timerTransition)
                }
            }
            .background { redFill }
            .clipShape(.capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, SpacingTokens.xxs)
        .padding(.vertical, SpacingTokens.xxxs)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    /// The glyph area: ▶ or ■ in the chosen morph, or the result.
    @ViewBuilder
    private var restMark: some View {
        switch result {
        case .succeeded where showsMark:
            Image(systemName: "checkmark")
                .font(TypographyTokens.standard.weight(.semibold))
                .foregroundStyle(ColorTokens.Status.success)
                .transition(.symbolEffect(.drawOn))
                .frame(width: RunSpecimenGlyph.size, height: RunSpecimenGlyph.size)
        case .failed where showsMark:
            Image(systemName: "exclamationmark")
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Status.error)
                .frame(width: RunSpecimenGlyph.size, height: RunSpecimenGlyph.size)
        case .succeeded, .failed:
            Color.clear.frame(width: RunSpecimenGlyph.size, height: RunSpecimenGlyph.size)
        default:
            LabRMGlyph(morph: options.morph, isStop: stage > 0, colour: glyphColour)
        }
    }

    private var glyphColour: Color {
        guard stage > 0 else { return ColorTokens.Text.primary }
        return options.fill == .plain ? ColorTokens.Status.error : LabRBMetrics.onFill
    }

    @ViewBuilder
    private var redFill: some View {
        switch options.fill {
        case .plain:
            Color.clear
        case .flood:
            GeometryReader { proxy in
                Circle()
                    .fill(ColorTokens.Status.error)
                    .frame(width: proxy.size.width * 2.4, height: proxy.size.width * 2.4)
                    .scaleEffect(stage > 0 ? 1 : 0.01)
                    .position(x: RunSpecimenGlyph.size / 2, y: proxy.size.height / 2)
            }
        default:
            Capsule().fill(ColorTokens.Status.error).opacity(stage > 0 ? 1 : 0)
        }
    }

    private var timerTransition: AnyTransition {
        switch options.grow {
        case .slideOut: .move(edge: .leading).combined(with: .opacity)
        case .roll: .push(from: .bottom)
        case .swap, .noTime: .opacity
        case .fadeAfter: .asymmetric(insertion: .opacity.animation(curve.delay(motion.settleDuration * 0.6)), removal: .opacity)
        }
    }

    private var curve: Animation {
        switch options.curve {
        case .spring: motion.standard
        case .smooth, .staged: motion.settle
        }
    }

    // MARK: Stages

    private func advance(_ phase: LabRBSimulation.Phase) {
        task?.cancel()
        switch phase {
        case .running:
            result = nil
            showsMark = true
            guard options.curve == .staged else { stage = 2; return }
            stage = 1
            task = Task { @MainActor in
                try? await Task.sleep(for: .seconds(motion.settleDuration * 0.55))
                guard !Task.isCancelled else { return }
                stage = 2
            }
        case .succeeded, .failed:
            end(with: phase)
        default:
            stage = 0
            result = nil
        }
    }

    private func end(with phase: LabRBSimulation.Phase) {
        stage = 0
        guard options.ending != .reverse else { result = nil; return }
        showsMark = options.ending == .together
        result = phase
        task = Task { @MainActor in
            if options.ending == .shrinkFirst {
                try? await Task.sleep(for: .seconds(motion.settleDuration))
                guard !Task.isCancelled else { return }
                showsMark = true
            }
            try? await Task.sleep(for: .seconds(LabRBHold.today.seconds))
            guard !Task.isCancelled else { return }
            result = nil
        }
    }
}

/// The running time as decided (K1): “5 s”, then “1:05”; W3 rolls the digits.
struct LabRMTimer: View {
    let started: Date
    let rolls: Bool

    var body: some View {
        TimelineView(.periodic(from: started, by: 1)) { context in
            let text = LabRBTimerFormat.seconds.text(context.date.timeIntervalSince(started))
            Text(text)
                .monospacedDigit()
                .contentTransition(rolls ? .numericText(countsDown: false) : .identity)
                .animation(rolls ? .default : nil, value: text)
        }
    }
}
