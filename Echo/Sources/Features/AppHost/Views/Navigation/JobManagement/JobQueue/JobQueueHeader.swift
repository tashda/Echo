import SwiftUI

/// Agent Jobs' tool header (one theme for every tool tab, round 37.1): its icon, title and
/// server, with Refresh and Open in Window on the line (37.2, 37.3). Open in Window was in the
/// window toolbar before round 45; New Job and Start/Stop stay on the Jobs pane (round 33).
struct JobQueueHeader: View {
    let viewModel: JobQueueViewModel
    let hostTab: WorkspaceTab?
    let serverName: String?

    @Environment(EnvironmentState.self) private var environmentState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ToolTabHeader(systemImage: WorkspaceTab.Kind.jobQueue.icon, tint: ColorTokens.accent, title: "Agent Jobs",
                      subtitle: Text(subtitle)) {
            ToolTabActionGroup {
                ToolTabActionButton(title: "Refresh", systemImage: "arrow.clockwise") {
                    Task { await viewModel.reloadJobs() }
                }
                if let hostTab {
                    ToolTabActionButton(title: "Open in Window", systemImage: "rectangle.portrait.and.arrow.right") {
                        if let sessionID = environmentState.popOutJobQueueTab(hostTab) {
                            openWindow(id: JobQueueWindow.sceneID, value: sessionID)
                        }
                    }
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
