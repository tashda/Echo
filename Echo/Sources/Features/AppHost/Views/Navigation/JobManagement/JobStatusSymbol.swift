import SwiftUI

/// A job's status in the jobs list (round 33, JC1 and JR1): one symbol for ready, running,
/// failed or disabled. A running job's symbol spins.
struct JobStatusSymbol: View {
    let status: JobQueueViewModel.JobListStatus

    var body: some View {
        switch status {
        case .running:
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(ColorTokens.Status.warning)
                .symbolEffect(.rotate, options: .repeat(.continuous))
                .help("Running")
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(ColorTokens.Status.error)
                .help("The last run failed")
        case .disabled:
            Image(systemName: "pause.circle")
                .foregroundStyle(ColorTokens.Text.tertiary)
                .help("Disabled")
        case .ready:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(ColorTokens.Status.success)
                .help("Enabled")
        }
    }
}

extension LayoutTokens {
    /// The Agent Jobs tab (round 33).
    enum AgentJobs {
        static let statusColumnWidth: CGFloat = SpacingTokens.lg2
    }
}
