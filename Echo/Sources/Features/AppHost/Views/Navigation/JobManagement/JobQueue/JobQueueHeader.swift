import SwiftUI

/// Agent Jobs' tool header (one theme for every tool tab, round 37.1): the sidebar's clock in the
/// jobs colour, its title and server, with Refresh on the line (37.2, 37.3). Open in New Window is
/// in the window toolbar (the owner, 2026-10-01); New Job and Start/Stop stay on the Jobs pane (round 33).
struct JobQueueHeader: View {
    let viewModel: JobQueueViewModel
    let hostTab: WorkspaceTab?
    let serverName: String?

    var body: some View {
        ToolTabHeader(systemImage: ExplorerNodeKind.agentJobs.symbol, tint: ColorTokens.Explorer.jobs, title: "Agent Jobs",
                      subtitle: Text(subtitle)) {
            ToolTabActionGroup {
                ToolTabActionButton(title: "Refresh", systemImage: "arrow.clockwise") {
                    Task { await viewModel.reloadJobs() }
                }
            }
        }
    }

    private var subtitle: String {
        let jobs = viewModel.jobs.count
        let count = jobs == 1 ? "1 job" : "\(jobs) jobs"
        guard let serverName, !serverName.isEmpty else { return count }
        return "\(serverName) · \(count)"
    }
}
