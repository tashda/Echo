import Observation
import SwiftUI

/// What the Run specimen shares with its controls: the simulated query and the selection.
@Observable @MainActor
final class RunSpecimenState {
    let simulation = LabRunSimulation()
    var hasSelection = false
}

/// Run as Echo has it today (QueryRunToolbarControl, commit 92d9b637), copied so the page stays a
/// snapshot: a standard toolbar button in a capsule of its own, accent while it would run only the
/// selection, the whole capsule red (prominent glass) with ■ and the timer while running, then ✓
/// or ! for a moment.
struct RunButtonSpecimen: View {
    let state: RunSpecimenState

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            toolbar
            editorCard
        }
        .padding(SpacingTokens.lg)
    }

    private var toolbar: some View {
        HStack(spacing: SpacingTokens.xs) {
            RunSpecimenCapsule { RunSpecimenGlyph(symbol: "sidebar.left") }
            Spacer(minLength: SpacingTokens.none)
            RunSpecimenButton(state: state)
            RunSpecimenCapsule {
                ForEach(["sparkles", "exclamationmark.triangle", "text.book.closed", "flowchart"], id: \.self) {
                    RunSpecimenGlyph(symbol: $0)
                }
            }
            RunSpecimenCapsule {
                ForEach(["magnifyingglass", "square.grid.2x2", "arrow.clockwise", "bell", "sidebar.right"], id: \.self) {
                    RunSpecimenGlyph(symbol: $0)
                }
            }
        }
    }

    /// The editor, with line 2 selected when Selection is on, and the inline result after a run.
    private var editorCard: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            line(1, "select *", selected: false)
            HStack(spacing: SpacingTokens.md) {
                line(2, "from employees.employee", selected: state.hasSelection)
                if case .succeeded(let rows, let seconds) = state.simulation.phase {
                    Text("✓ \(rows.formatted()) rows · \(seconds.formatted(.number.precision(.fractionLength(1)))) s")
                        .foregroundStyle(ColorTokens.Status.success)
                        .transition(.opacity)
                }
            }
            Spacer(minLength: SpacingTokens.none)
        }
        .font(TypographyTokens.code)
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .workspaceCard()
    }

    private func line(_ number: Int, _ text: String, selected: Bool) -> some View {
        HStack(spacing: SpacingTokens.md) {
            Text("\(number)").foregroundStyle(ColorTokens.Text.tertiary)
            Text(text)
                .background(selected ? ColorTokens.accent.opacity(0.25) : .clear)
        }
    }
}

/// The copied control. Idle and result states are a plain toolbar glyph; running is the system's
/// prominent glass, tinted red, filling the whole capsule.
private struct RunSpecimenButton: View {
    let state: RunSpecimenState
    @Environment(\.echoMotion) private var motion

    private var phase: LabRunPhase { state.simulation.phase }

    var body: some View {
        Group {
            if case .running(let started) = phase {
                Button { state.simulation.cancel() } label: {
                    Label {
                        Text(started, style: .timer).monospacedDigit()
                    } icon: {
                        Image(systemName: "stop.fill")
                    }
                }
                .labelStyle(.titleAndIcon)
                .buttonStyle(.glassProminent)
                .tint(ColorTokens.Status.error)
                .help("Cancel (⌥⌘.)")
            } else {
                RunSpecimenCapsule {
                    Button { state.simulation.start() } label: {
                        Image(systemName: symbol)
                            .foregroundStyle(color)
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: RunSpecimenGlyph.size, height: RunSpecimenGlyph.size)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(state.hasSelection ? "Run Selection (⌘↩)" : "Run (⌘↩)")
                }
            }
        }
        .contextMenu {
            Button("Run", systemImage: "play.fill") { state.simulation.start() }
            Button("Run Statement at Cursor", systemImage: "text.line.first.and.arrowtriangle.forward") { state.simulation.start() }
            Button("Explain", systemImage: "flowchart") {}
            Button("Explain Analyze", systemImage: "flowchart.fill") {}
        }
        .animation(motion.standard, value: phase)
        .animation(motion.hover, value: state.hasSelection)
    }

    private var symbol: String {
        switch phase {
        case .succeeded: "checkmark"
        case .failed: "exclamationmark"
        default: "play.fill"
        }
    }

    private var color: Color {
        switch phase {
        case .succeeded: ColorTokens.Status.success
        case .failed: ColorTokens.Status.error
        default: state.hasSelection ? ColorTokens.accent : ColorTokens.Text.primary
        }
    }
}

/// A toolbar glass capsule, as macOS draws a group of toolbar items.
struct RunSpecimenCapsule<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: SpacingTokens.none) { content() }
            .padding(.horizontal, SpacingTokens.xxs)
            .padding(.vertical, SpacingTokens.xxxs)
            .glassEffect(.regular, in: .capsule)
    }
}

/// A plain toolbar glyph.
struct RunSpecimenGlyph: View {
    static let size: CGFloat = 28
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(TypographyTokens.standard)
            .foregroundStyle(ColorTokens.Text.primary)
            .frame(width: Self.size, height: Self.size)
    }
}
