import Observation
import SwiftUI

/// What the Run specimen shares with its controls: the simulated query and the selection.
@Observable @MainActor
final class RunSpecimenState {
    let simulation = LabRunSimulation()
    var hasSelection = false
    /// Settings › Appearance › Line Number Gutter.
    var gutter: EditorGutterLook = .subtle
    /// Settings › Appearance › Statement Focus (on by default).
    var statementFocus = true
    /// A failing line shows a red dot beside its number.
    var showsError = false

    /// The Spec page forces a state: a gutter style, or the error dot.
    func force(_ key: String?) {
        switch key {
        case "column": gutter = .column
        case "lane": gutter = .lane
        case "subtle": gutter = .subtle
        case "hairline": gutter = .hairline
        case "error": showsError = true
        default: break
        }
    }
}

enum EditorGutterLook: String, CaseIterable, Identifiable {
    case subtle = "Subtle (default)", column = "Column", lane = "Lane", hairline = "Hairline"
    var id: String { rawValue }
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

    /// The editor card as `SQLTextView` and `LineNumberRulerView` draw it (rounds 28.1 to 28.4):
    /// the gutter in its chosen style, no band on the caret's line (its number in the text
    /// colour), the statement bracket and grey Run arrow when the script has more than one
    /// statement, an error dot, the rounded system selection, and the run note after a run.
    private var editorCard: some View {
        let lines = ["select *", "from employees.employee", "where hire_date > '2020-01-01';", "", "select count(*) from departments;"]
        let gutterWidth: CGFloat = 4 + 5 + 2 + 2 * 6.7 + LayoutTokens.EditorGutter.numberTrailing
        return ZStack(alignment: .topLeading) {
            gutterBackground(width: gutterWidth)
            // No band on the caret's line (round 28.3): the anchor marks where it was.
            Color.clear.frame(height: 20).offset(y: 8 + 20 * 1).specAnchor("2.4")
            if state.statementFocus {
                Capsule().fill(ColorTokens.accent.opacity(LayoutTokens.EditorGutter.statementBracketOpacity))
                    .frame(width: LayoutTokens.EditorGutter.statementBracketWidth, height: 60 - LayoutTokens.EditorGutter.statementBracketInset * 2)
                    .offset(x: gutterWidth - LayoutTokens.EditorGutter.numberTrailing + LayoutTokens.EditorGutter.statementBracketGap,
                            y: 8 + LayoutTokens.EditorGutter.statementBracketInset)
                    .specAnchor("3.1")
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, text in
                    HStack(spacing: 0) {
                        ZStack(alignment: .leading) {
                            if state.showsError && index == 2 {
                                Circle().fill(ColorTokens.Status.error).frame(width: 5, height: 5).offset(x: LayoutTokens.EditorGutter.markerLeading).specAnchor("2.3")
                            } else if state.statementFocus && index == 0 {
                                Image(systemName: "arrowtriangle.right.fill").font(.system(size: 8)).foregroundStyle(ColorTokens.Text.tertiary)
                                    .offset(x: LayoutTokens.EditorGutter.markerLeading).specAnchor("3.2")
                            }
                            Text("\(index + 1)").font(.system(size: 11).monospacedDigit())
                                .foregroundStyle(index == 1 ? ColorTokens.Text.primary : ColorTokens.Text.tertiary)
                                .frame(width: gutterWidth - LayoutTokens.EditorGutter.numberTrailing, alignment: .trailing)
                                .optionalSpecAnchor(index == 0 ? "2.2" : nil)
                        }
                        .frame(width: gutterWidth, alignment: .leading)
                        HStack(spacing: LayoutTokens.EditorGutter.runNoteGap) {
                            Text(text).background(index == 1 && state.hasSelection ? Color(nsColor: .selectedTextBackgroundColor) : .clear,
                                                  in: RoundedRectangle(cornerRadius: SpacingTokens.nano))
                            if index == 2, case .succeeded(let rows, let seconds) = state.simulation.phase {
                                Text("✓ \(rows.formatted()) rows · \(seconds.formatted(.number.precision(.fractionLength(1)))) s")
                                    .font(TypographyTokens.detail).foregroundStyle(.green).transition(.opacity).specAnchor("3.3")
                            }
                        }
                    }
                    .frame(height: 20)
                }
            }
            .padding(.top, 8)
        }
        .font(TypographyTokens.code)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .workspaceCard()
        .specAnchor("1.1")
    }

    @ViewBuilder
    private func gutterBackground(width: CGFloat) -> some View {
        switch state.gutter {
        case .subtle: EmptyView()
        case .column:
            HStack(spacing: 0) {
                Rectangle().fill(ColorTokens.Text.primary.opacity(0.04)).frame(width: width)
                    .overlay(alignment: .trailing) { Rectangle().fill(.separator).frame(width: LayoutTokens.EditorGutter.edgeWidth) }
                Spacer()
            }.specAnchor("2.1")
        case .lane:
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: LayoutTokens.EditorGutter.laneCornerRadius, style: .continuous)
                    .fill(ColorTokens.Text.primary.opacity(0.04))
                    .frame(width: max(width - LayoutTokens.EditorGutter.laneInset * 2, 0))
                    .padding(LayoutTokens.EditorGutter.laneInset)
                Spacer()
            }.specAnchor("2.1")
        case .hairline:
            HStack(spacing: 0) {
                Spacer().frame(width: width - LayoutTokens.EditorGutter.edgeWidth)
                Rectangle().fill(.separator).frame(width: LayoutTokens.EditorGutter.edgeWidth)
                Spacer()
            }.specAnchor("2.1")
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
        .specAnchor(runNumber)
        .animation(motion.standard, value: phase)
        .animation(motion.hover, value: state.hasSelection)
    }

    /// The Spec element the button is showing right now.
    private var runNumber: String {
        switch phase {
        case .running: "4.3"
        case .succeeded, .failed: "4.4"
        default: state.hasSelection ? "4.2" : "4.1"
        }
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

private extension View {
    /// `specAnchor` only when there is a number.
    @ViewBuilder func optionalSpecAnchor(_ number: String?) -> some View {
        if let number { specAnchor(number) } else { self }
    }
}
