import SwiftUI

/// Agent Jobs' tool header (one theme for every tool tab, round 37.1): the sidebar's clock in the
/// jobs colour, its title, server and count. Its buttons are in the window toolbar: New Job,
/// Start/Stop and Refresh in its section (round 37.5, `JobListView.toolbarGroups`), Open in New
/// Window as its own group (the owner, 2026-10-01).
struct JobQueueHeader: View {
    let viewModel: JobQueueViewModel
    let serverName: String?

    var body: some View {
        ToolTabHeader(systemImage: ExplorerNodeKind.agentJobs.symbol, tint: ColorTokens.Explorer.jobs, title: "Agent Jobs",
                      subtitle: Text(subtitle))
    }

    private var subtitle: String {
        let jobs = viewModel.jobs.count
        let count = jobs == 1 ? "1 job" : "\(jobs) jobs"
        guard let serverName, !serverName.isEmpty else { return count }
        return "\(serverName) · \(count)"
    }
}
