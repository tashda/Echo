import SwiftUI

/// What Run shows inside its capsule: the symbol, the red, the time and the tooltip.
extension QueryRunToolbarControl {
    /// ▶, ■ (replaced in place, M1), a spinner while stopping, or after a run a ✓ that draws
    /// itself (E1) or a !.
    @ViewBuilder
    var glyph: some View {
        Group {
            if isStopping {
                ProgressView().controlSize(.small)
            } else if result == .succeeded, stage == .rest {
                Image(systemName: "checkmark")
                    .transition(.symbolEffect(.drawOn))
            } else {
                Image(systemName: symbol)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .font(TypographyTokens.standard)
        .foregroundStyle(glyphColour)
        .frame(width: LayoutTokens.Toolbar.glyph, height: LayoutTokens.Toolbar.glyph)
    }

    /// The time while running (K1), or Stopping once the cancel is sent (J1).
    @ViewBuilder
    func runningWords(started: Date) -> some View {
        Group {
            if isStopping {
                Text("Stopping")
            } else {
                TimelineView(.periodic(from: started, by: 1)) { context in
                    Text(ElapsedTimeText.format(context.date.timeIntervalSince(started))).monospacedDigit()
                }
            }
        }
        .font(TypographyTokens.standard)
        .foregroundStyle(ColorTokens.Text.onFill)
    }

    /// F1: the capsule fades to red while running, dimmer while stopping.
    var redFill: some View {
        Capsule()
            .fill(ColorTokens.Status.error)
            .opacity(stage == .rest ? 0 : (isStopping ? 0.6 : 1))
    }

    private var symbol: String {
        if stage != .rest { return "stop.fill" }
        return result == .failed ? "exclamationmark" : "play.fill"
    }

    private var glyphColour: Color {
        if stage != .rest { return ColorTokens.Text.onFill }
        switch result {
        case .succeeded: return ColorTokens.Status.success
        case .failed: return ColorTokens.Status.error
        case nil:
            if !canRun { return ColorTokens.Text.tertiary }
            return runsSelection ? ColorTokens.accent : ColorTokens.Text.primary
        }
    }

    // MARK: Tooltip

    var helpText: String {
        QueryRunButtonText.help(helpState, database: tab?.activeDatabaseName, server: serverName)
    }

    private var helpState: QueryRunButtonText.State {
        if isStopping { return .stopping }
        if isRunning { return .running }
        guard canRun else { return .nothingToRun }
        return .ready(runsSelection: runsSelection)
    }

    private var serverName: String? {
        guard let connection = tab?.connection else { return nil }
        return connection.connectionName.isEmpty ? connection.host : connection.connectionName
    }
}
