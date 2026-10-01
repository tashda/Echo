import SwiftUI

/// The result a Run control shows for a moment after a run.
struct LabRunResultLabel: View {
    let phase: LabRunPhase

    var body: some View {
        switch phase {
        case .succeeded(let rows, let seconds):
            Label("\(rows.formatted()) rows · \(seconds.formatted(.number.precision(.fractionLength(1)))) s", systemImage: "checkmark")
                .foregroundStyle(ColorTokens.Status.success)
        case .failed(let line):
            Label("Failed on line \(line)", systemImage: "exclamationmark.octagon.fill")
                .foregroundStyle(ColorTokens.Status.error)
        case .cancelled:
            Label("Cancelled", systemImage: "stop.fill")
                .foregroundStyle(ColorTokens.Text.secondary)
        default:
            EmptyView()
        }
    }
}

/// The elapsed time of a running query.
struct LabRunTimer: View {
    let started: Date
    var body: some View {
        Text(started, style: .timer).monospacedDigit()
    }
}

// MARK: - 1 · Quiet glyph

struct LabRunQuietGlyph: View {
    let simulation: LabRunSimulation

    var body: some View {
        HStack(spacing: SpacingTokens.none) {
            Button(action: simulation.toggle) { glyph }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Run Statement at Cursor") {}
                    Button("Explain") {}
                    Button("Explain Analyze") {}
                }
                .help(simulation.phase.isRunning ? "Cancel (⌥⌘.)" : "Run (⌘↩)")
            ForEach(["sparkles", "exclamationmark.triangle", "text.book.closed", "flowchart"], id: \.self) {
                LabRunGlyph(symbol: $0)
            }
        }
        .padding(.horizontal, SpacingTokens.xxs)
        .glassEffect(.regular, in: .capsule)
    }

    @ViewBuilder
    private var glyph: some View {
        switch simulation.phase {
        case .running(let started):
            HStack(spacing: SpacingTokens.xxs) {
                Image(systemName: "stop.fill")
                LabRunTimer(started: started)
            }
            .font(TypographyTokens.detail.weight(.semibold))
            .foregroundStyle(ColorTokens.Status.error)
            .padding(.horizontal, SpacingTokens.xs)
            .frame(height: LabRound15Metrics.toolbarGlyph)
            .background(ColorTokens.Status.error.opacity(0.14), in: .capsule)
        case .succeeded:
            symbol("checkmark", ColorTokens.Status.success)
        case .failed:
            symbol("exclamationmark", ColorTokens.Status.error)
        default:
            symbol("play.fill", ColorTokens.Text.primary)
        }
    }

    private func symbol(_ name: String, _ color: Color) -> some View {
        Image(systemName: name)
            .font(TypographyTokens.standard)
            .foregroundStyle(color)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: LabRound15Metrics.toolbarGlyph, height: LabRound15Metrics.toolbarGlyph)
    }
}

// MARK: - 2 · In the footer

struct LabRunFooterPill: View {
    let simulation: LabRunSimulation

    var body: some View {
        Button(action: simulation.toggle) {
            content
                .font(TypographyTokens.detail.weight(.medium))
                .padding(.horizontal, SpacingTokens.sm)
                .frame(height: LabRound15Metrics.footerHeight)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(glass, in: .capsule)
    }

    private var glass: Glass {
        simulation.phase.isRunning ? .regular.tint(ColorTokens.Status.error.opacity(0.25)).interactive() : .regular.interactive()
    }

    @ViewBuilder
    private var content: some View {
        switch simulation.phase {
        case .running(let started):
            HStack(spacing: SpacingTokens.xxs2) {
                ProgressView().controlSize(.mini)
                LabRunTimer(started: started)
                Image(systemName: "stop.fill").foregroundStyle(ColorTokens.Status.error)
            }
        case .idle:
            HStack(spacing: SpacingTokens.xxs2) {
                Image(systemName: "play.fill").foregroundStyle(ColorTokens.accent)
                Text("Run")
                Text("⌘↩").foregroundStyle(ColorTokens.Text.tertiary)
            }
        default:
            LabRunResultLabel(phase: simulation.phase)
        }
    }
}

// MARK: - 3 · On the editor card

struct LabRunCornerButton: View {
    let simulation: LabRunSimulation
    let isHoveringCard: Bool

    private var isShown: Bool { isHoveringCard || simulation.phase != .idle }

    var body: some View {
        Button(action: simulation.toggle) {
            content
                .font(TypographyTokens.detail.weight(.semibold))
                .padding(.horizontal, simulation.phase == .idle ? SpacingTokens.none : SpacingTokens.xs)
                .frame(minWidth: LabRound15Metrics.toolbarGlyph, minHeight: LabRound15Metrics.toolbarGlyph)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .opacity(isShown ? 1 : 0)
        .scaleEffect(isShown ? 1 : 0.8)
        .padding(SpacingTokens.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    @ViewBuilder
    private var content: some View {
        switch simulation.phase {
        case .running(let started):
            HStack(spacing: SpacingTokens.xxs2) {
                LabRunRing()
                LabRunTimer(started: started)
                Image(systemName: "stop.fill").foregroundStyle(ColorTokens.Status.error)
            }
        case .idle:
            Image(systemName: "play.fill").foregroundStyle(ColorTokens.accent)
        default:
            LabRunResultLabel(phase: simulation.phase)
        }
    }
}

/// The ring that turns while the query runs: the system's small spinner.
struct LabRunRing: View {
    var body: some View {
        ProgressView().controlSize(.mini)
    }
}
