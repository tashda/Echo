import SwiftUI

/// Round 45: where a tool's main action lives.
enum LabMAPlace: String, CaseIterable {
    case header = "MA0 · In the tool's header, as 37.3 drew it"
    case runSlotWords = "MA1 · Every main action in Run's place, symbol and word"
    case byKindWords = "MA2 · Start and stop in Run's place with a word; New as a +"
    case byKindPlain = "MA3 · Exactly Run: a plain ▶ for start and stop, a plain + for New"

    var summary: String {
        switch self {
        case .header: "Accepted in 37.3 (PA1): a glass capsule at the end of the header line. The toolbar has nothing for the tool."
        case .runSlotWords: "One glass capsule where Run sits in a query tab: ▶ Start Trace, + New Policy, ⏸ Pause."
        case .byKindWords: "Starting and stopping something takes Run's place and behaves like Run; creating something is a + in a glass circle of its own."
        case .byKindPlain: "The same buttons as the editor: ▶ is Run's button (tooltip Start Trace, ⌘↩), + is the tab strip's +. No words."
        }
    }
}

/// How the main action looks while what it started is running.
enum LabMARunning: String, CaseIterable {
    case run = "RN0 · Run's running look: red, ■, the time after 3 s (round 24)"
    case dot = "RN1 · 37.3's ST1: Stop with a pulsing red dot"
}

/// Playground: the trace is running or not.
enum LabMAState: String, CaseIterable {
    case resting = "Resting"
    case running = "Running"
}

/// A tool's main action, and whether it starts something or creates something.
struct LabMAAction {
    enum Kind { case startStop, create }
    let kind: Kind
    let title: String
    let runningTitle: String
    let symbol: String
    /// A monitor runs from the moment it opens: running, it offers ⏸, not Run's red ■.
    var runsRed = true

    static let startTrace = LabMAAction(kind: .startStop, title: "Start Trace", runningTitle: "Stop Trace", symbol: "play.fill")
    static let newPolicy = LabMAAction(kind: .create, title: "New Policy", runningTitle: "New Policy", symbol: "plus")
    static let pause = LabMAAction(kind: .startStop, title: "Resume", runningTitle: "Pause", symbol: "play.fill", runsRed: false)
}

/// Echo's window toolbar, right side: the main action's group, then Search · Overview · Refresh ·
/// Bell · Inspector.
struct LabMAToolbar: View {
    let action: LabMAAction?
    let place: LabMAPlace
    let runningLook: LabMARunning
    let running: Bool
    var todayExtras: [String] = []

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            RunSpecimenCapsule { RunSpecimenGlyph(symbol: "sidebar.left") }
            RunSpecimenCapsule { RunSpecimenGlyph(symbol: "folder") }
            Spacer(minLength: SpacingTokens.none)
            if !todayExtras.isEmpty {
                RunSpecimenCapsule { ForEach(todayExtras, id: \.self) { RunSpecimenGlyph(symbol: $0) } }
            }
            if let action, place != .header { mainAction(action) }
            RunSpecimenCapsule {
                ForEach(["magnifyingglass", "square.grid.2x2", "arrow.clockwise", "bell", "sidebar.right"], id: \.self) {
                    RunSpecimenGlyph(symbol: $0)
                }
            }
        }
    }

    @ViewBuilder
    private func mainAction(_ action: LabMAAction) -> some View {
        let words = place == .runSlotWords || (place == .byKindWords && action.kind == .startStop)
        if action.kind == .startStop && running && !action.runsRed {
            RunSpecimenCapsule {
                HStack(spacing: SpacingTokens.xxs) {
                    Image(systemName: "pause.fill").font(TypographyTokens.standard)
                    if words { Text(action.runningTitle).font(TypographyTokens.standard) }
                }
                .padding(.horizontal, words ? SpacingTokens.xs : SpacingTokens.none)
                .frame(minWidth: RunSpecimenGlyph.size, minHeight: RunSpecimenGlyph.size)
            }
            .help(action.runningTitle)
        } else if action.kind == .startStop && running {
            runningButton(action, words: words)
        } else if action.kind == .create && place != .runSlotWords {
            RunSpecimenGlyph(symbol: "plus")
                .frame(width: RunSpecimenGlyph.size + SpacingTokens.xxs, height: RunSpecimenGlyph.size + SpacingTokens.xxs)
                .glassEffect(.regular.interactive(), in: Circle())
                .help(action.title)
        } else {
            RunSpecimenCapsule {
                HStack(spacing: SpacingTokens.xxs) {
                    Image(systemName: action.symbol).font(TypographyTokens.standard)
                    if words { Text(action.title).font(TypographyTokens.standard) }
                }
                .padding(.horizontal, words ? SpacingTokens.xs : SpacingTokens.none)
                .frame(minWidth: RunSpecimenGlyph.size, minHeight: RunSpecimenGlyph.size)
            }
            .help(action.title)
        }
    }

    @ViewBuilder
    private func runningButton(_ action: LabMAAction, words: Bool) -> some View {
        switch runningLook {
        case .run:
            Button { } label: {
                Label {
                    Text(words ? "\(action.runningTitle) · 0:42" : "0:42").monospacedDigit()
                } icon: { Image(systemName: "stop.fill") }
            }
            .labelStyle(.titleAndIcon)
            .buttonStyle(.glassProminent)
            .tint(ColorTokens.Status.error)
            .help(action.runningTitle)
        case .dot:
            RunSpecimenCapsule {
                HStack(spacing: SpacingTokens.xxs2) {
                    LabMAPulsingDot()
                    if words { Text(action.runningTitle).font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary) }
                    else { Image(systemName: "stop.fill").font(TypographyTokens.standard) }
                }
                .padding(.horizontal, SpacingTokens.xs)
                .frame(minHeight: RunSpecimenGlyph.size)
            }
            .help(action.runningTitle)
        }
    }
}

/// 37.3's ST1 dot.
struct LabMAPulsingDot: View {
    @State private var on = false
    @Environment(\.echoMotion) private var motion

    var body: some View {
        Circle().fill(ColorTokens.Status.error)
            .frame(width: SpacingTokens.xxs2, height: SpacingTokens.xxs2)
            .opacity(on ? 0.35 : 1)
            .onAppear { withAnimation(motion.standard.repeatForever(autoreverses: true)) { on = true } }
    }
}

/// A whole tool tab under the toolbar: toolbar, strip (TP5), the one-line header (UH5) and rows.
struct LabMAExhibit: View {
    let tool: LabTTTool
    let action: LabMAAction
    let place: LabMAPlace
    let runningLook: LabMARunning
    let running: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            LabMAToolbar(action: action, place: place, runningLook: runningLook, running: running)
            LabTTTab(tool: tool, look: look, running: running)
        }
        .padding(.top, SpacingTokens.sm)
        .padding(.horizontal, SpacingTokens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ColorTokens.Workspace.canvas)
    }

    private var look: LabTTLook {
        var look = LabTTLook()
        look.header = .oneLine
        look.primaryInHeader = place == .header
        return look
    }
}
