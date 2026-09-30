import SwiftUI

/// The symbol in a Run button: ▶ (or the chosen icon), ■ while running, ✓ or ! after. It stays one
/// Image across states so the symbol can change in place.
struct LabRBGlyph: View {
    let button: LabRBButton

    private var look: LabRBLook { button.look }
    private var visual: LabRBButton.Visual { button.visual }
    private var motion: EchoMotion { button.motion }

    var body: some View {
        ZStack {
            if look.form == .disc {
                Circle().fill(discColour).frame(width: LabRBMetrics.disc, height: LabRBMetrics.disc)
            }
            mark
        }
        .frame(width: LabRBMetrics.glyph, height: LabRBMetrics.glyph)
        .overlay(alignment: .topTrailing) { selectionDot }
        .scaleEffect(look.hover == .grow && isHoveredAtRest ? 1.18 : 1)
        .offset(x: look.hover == .nudge && isHoveredAtRest ? SpacingTokens.xxxs : SpacingTokens.none)
        .symbolEffect(.wiggle.forward, value: button.noteCount)
    }

    @ViewBuilder
    private var mark: some View {
        if isSpinning {
            ProgressView().controlSize(.small)
        } else if look.result == .drawn, case .succeeded = visual {
            Image(systemName: "checkmark")
                .font(TypographyTokens.standard.weight(.semibold))
                .foregroundStyle(markColour)
                .transition(.symbolEffect(.drawOn))
        } else {
            Image(systemName: symbol)
                .font(TypographyTokens.standard)
                .foregroundStyle(markColour)
                .contentTransition(look.change == .magic
                                   ? .symbolEffect(.replace.magic(fallback: .replace))
                                   : .symbolEffect(.replace))
                .symbolEffect(.breathe, isActive: loops(.breathe))
                .symbolEffect(.pulse, isActive: loops(.pulse))
                .overlay { if isRunning && look.running == .ring { LabRBRing(spins: motion.allowsLoopingEffects) } }
        }
    }

    // MARK: State

    private var isRunning: Bool { button.isRunning }
    private var isHoveredAtRest: Bool { button.isHovered && visual == .rest && !button.isSample && button.canRun }
    private var isSpinning: Bool { isRunning && look.running == .spinner && !button.isHovered }

    private func loops(_ effect: LabRBRunningMotion) -> Bool {
        isRunning && look.runningMotion == effect && motion.allowsLoopingEffects
    }

    private var symbol: String {
        switch visual {
        case .running: return look.stopIcon.symbol
        case .succeeded where look.result != .flash: return "checkmark"
        case .failed where look.result != .flash: return "exclamationmark"
        default:
            if look.memory == .lastMode, button.simulation.lastMode != .run, !button.isSample {
                return button.simulation.lastMode.symbol
            }
            return look.icon.symbol
        }
    }

    /// The glyph's own colour; on a solid fill (disc, prominent) it is the colour on the fill.
    private var markColour: Color {
        if look.form == .disc || (look.form == .prominent && !isFlashResult) { return onFillColour }
        if case .running = visual { return button.onShell }
        switch visual {
        case .succeeded where look.result != .flash: return ColorTokens.Status.success
        case .failed where look.result != .flash: return ColorTokens.Status.error
        default: return button.restColour
        }
    }

    /// Label colour and quiet grey fills take the card colour on top; coloured fills take white.
    private var onFillColour: Color {
        if case .running = visual { return LabRBMetrics.onFill }
        if visual == .rest && (look.colour == .primary || look.colour == .secondary) && !button.isDimmed
            && button.restColour != ColorTokens.accent {
            return ColorTokens.Workspace.card
        }
        return LabRBMetrics.onFill
    }

    private var discColour: Color {
        switch visual {
        case .running: ColorTokens.Status.error
        case .succeeded where look.result != .flash && look.result != .nothing: ColorTokens.Status.success
        case .failed where look.result != .flash && look.result != .nothing: ColorTokens.Status.error
        default: button.restColour
        }
    }

    private var isFlashResult: Bool {
        switch visual {
        case .succeeded, .failed: look.result == .flash
        default: false
        }
    }

    @ViewBuilder
    private var selectionDot: some View {
        if look.selection == .dot && button.hasSelection && visual == .rest && !button.isSample {
            Circle()
                .fill(ColorTokens.accent)
                .frame(width: LabRBMetrics.dot, height: LabRBMetrics.dot)
                .offset(x: -SpacingTokens.xxxs, y: SpacingTokens.xxxs)
                .transition(.scale.combined(with: .opacity))
        }
    }
}

/// R2: a thin red ring that spins around ■ (still when motion is reduced).
struct LabRBRing: View {
    let spins: Bool

    var body: some View {
        TimelineView(.animation(paused: !spins)) { context in
            let turns = spins ? context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1) : 0
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(ColorTokens.Status.error, style: StrokeStyle(lineWidth: LabRBMetrics.ringWidth, lineCap: .round))
                .frame(width: LabRBMetrics.ring, height: LabRBMetrics.ring)
                .rotationEffect(.degrees(turns * 360))
        }
    }
}

/// P3: a soft band of light sweeping across the glass every 1.6 s.
struct LabRBShimmer: View {
    var body: some View {
        TimelineView(.animation) { context in
            let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.6) / 1.6
            GeometryReader { proxy in
                LinearGradient(colors: [.clear, ColorTokens.Status.error.opacity(0.35), .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: proxy.size.width * 0.6)
                    .offset(x: (phase * 1.6 - 0.6) * proxy.size.width)
            }
        }
        .allowsHitTesting(false)
    }
}
