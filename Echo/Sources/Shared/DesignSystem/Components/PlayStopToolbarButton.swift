import SwiftUI

/// Reusable play/stop toggle button for toolbars.
///
/// Used by Activity Monitor (play/pause streaming) and SQL Agent Jobs (start/stop job).
/// Shows a green play icon when stopped, red stop icon when running,
/// with a symbol replace transition.
struct PlayStopToolbarButton: View {
    let isRunning: Bool
    let runningLabel: String
    let stoppedLabel: String
    let action: () -> Void

    init(
        isRunning: Bool,
        runningLabel: String = "Stop",
        stoppedLabel: String = "Start",
        action: @escaping () -> Void
    ) {
        self.isRunning = isRunning
        self.runningLabel = runningLabel
        self.stoppedLabel = stoppedLabel
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: isRunning ? "stop.fill" : "play.fill")
                .foregroundStyle(isRunning ? .red : .green)
                .contentTransition(.symbolEffect(.replace))
        }
        .help(isRunning ? runningLabel : stoppedLabel)
    }
}
