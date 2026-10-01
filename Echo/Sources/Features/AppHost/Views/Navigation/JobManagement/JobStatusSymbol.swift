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
    /// The Agent Jobs tab and its sheets (round 33).
    enum AgentJobs {
        /// The jobs list's Status column (JC1).
        static let statusColumnWidth: CGFloat = SpacingTokens.lg2
        /// New Step / Edit Step (round 33.2, NS4): the command at the left, the settings at the right.
        static let stepSheetMinWidth: CGFloat = 760
        static let stepSheetMinHeight: CGFloat = 480
        static let stepSidebarWidth: CGFloat = 300
        static let stepCommandMinHeight: CGFloat = SpacingTokens.xxxl * 3
    }
}
