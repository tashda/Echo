import SwiftUI
import SQLServerKit

// MARK: - Agent Job Row Views

extension ObjectBrowserSidebarView {

    @ViewBuilder
    func agentJobsContent(session: ConnectionSession, jobs: [ObjectBrowserSidebarViewModel.AgentJobItem], isLoading: Bool) -> some View {
        agentJobsOverviewButton(session: session)

        if isLoading {
            agentJobsLoadingIndicator()
        } else if !jobs.isEmpty {
            ForEach(jobs) { job in
                agentJobRow(job: job, session: session)
            }
        }

        // New Job button -- at bottom of list
        newJobButton(session: session)
    }

    func agentJobsOverviewButton(session: ConnectionSession) -> some View {
        Button {
            environmentState.openJobQueueTab(for: session)
        } label: {
            SidebarRow(
                depth: 1,
                icon: .system("list.bullet.rectangle"),
                label: "Agent Jobs Overview",
                iconColor: projectStore.globalSettings.sidebarColoredIcons ? ExplorerSidebarPalette.jobs : ExplorerSidebarPalette.monochrome
            )
        }
        .buttonStyle(.plain)
    }

    func agentJobsLoadingIndicator() -> some View {
        SidebarRow(depth: 1, icon: .none, label: "Loading jobs\u{2026}", labelColor: ColorTokens.Text.secondary, labelFont: TypographyTokens.detail) {
            ProgressView()
                .controlSize(.mini)
        }
    }

    func newJobButton(session: ConnectionSession) -> some View {
        Button {
            viewModel.newJobSessionID = session.connection.id
            viewModel.showNewJobSheet = true
        } label: {
            SidebarRow(
                depth: 1,
                icon: .system("plus.circle"),
                label: "New Job\u{2026}",
                iconColor: ColorTokens.Text.tertiary,
                labelColor: ColorTokens.Text.tertiary
            )
        }
        .buttonStyle(.plain)
    }

    func agentJobRow(job: ObjectBrowserSidebarViewModel.AgentJobItem, session: ConnectionSession) -> some View {
        let statusColor = job.enabled
            ? agentJobStatusColor(job.lastOutcome, enabled: true)
            : ColorTokens.Text.quaternary

        return Button {
            environmentState.openJobQueueTab(for: session, selectJobID: job.name)
        } label: {
            SidebarRow(
                depth: 1,
                icon: .system("clock"),
                label: job.name,
                iconColor: statusColor,
                labelColor: job.enabled ? ColorTokens.Text.primary : ColorTokens.Text.secondary
            ) {
                if !job.enabled {
                    Text("Disabled")
                        .font(SidebarRowConstants.trailingFont)
                        .foregroundStyle(ColorTokens.Text.quaternary)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                environmentState.openJobQueueTab(for: session, selectJobID: job.name)
            } label: {
                Label("Open in Job Management", systemImage: "list.bullet.rectangle")
            }
        }
    }

    func agentJobStatusColor(_ outcome: String?, enabled: Bool) -> Color {
        guard enabled else { return ColorTokens.Text.primary.opacity(0.2) }
        switch outcome?.lowercased() {
        case "succeeded": return .green
        case "failed": return .red
        case "in progress": return .orange
        case "retry": return .yellow
        case "canceled": return ColorTokens.Text.primary.opacity(0.3)
        default: return ColorTokens.Text.primary.opacity(0.2)
        }
    }
}
