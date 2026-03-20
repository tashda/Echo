import SwiftUI
import SQLServerKit

// MARK: - Agent Job Row Views

extension ObjectBrowserSidebarView {

    @ViewBuilder
    func agentJobsContent(session: ConnectionSession, jobs: [ObjectBrowserSidebarViewModel.AgentJobItem], isLoading: Bool) -> some View {
        agentJobsOverviewButton(session: session)
            .contextMenu {
                Button {
                    environmentState.openJobQueueTab(for: session)
                } label: {
                    Label("Open in Tab", systemImage: "list.bullet.rectangle")
                }
                Button {
                    let sessionID = environmentState.prepareJobQueueWindow(for: session)
                    openWindow(id: JobQueueWindow.sceneID, value: sessionID)
                } label: {
                    Label("Open in New Window", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }

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
        let colored = projectStore.globalSettings.sidebarIconColorMode == .colorful
        return Button {
            environmentState.openJobQueueTab(for: session)
        } label: {
            SidebarRow(
                depth: 1,
                icon: .system("list.bullet.rectangle"),
                label: "Agent Jobs Overview",
                iconColor: ExplorerSidebarPalette.folderIconColor(title: "Agent Jobs", colored: colored)
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
                label: "New Job",
                iconColor: ColorTokens.Text.tertiary,
                labelColor: ColorTokens.Text.tertiary
            )
        }
        .buttonStyle(.plain)
    }

    func agentJobRow(job: ObjectBrowserSidebarViewModel.AgentJobItem, session: ConnectionSession) -> some View {
        let colored = projectStore.globalSettings.sidebarIconColorMode == .colorful
        let statusColor = job.enabled
            ? agentJobStatusColor(job.lastOutcome, enabled: true, colored: colored)
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
                Label("Open in Tab", systemImage: "list.bullet.rectangle")
            }
            Button {
                let sessionID = environmentState.prepareJobQueueWindow(for: session, selectJobID: job.name)
                openWindow(id: JobQueueWindow.sceneID, value: sessionID)
            } label: {
                Label("Open in New Window", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
    }

    func agentJobStatusColor(_ outcome: String?, enabled: Bool, colored: Bool = true) -> Color {
        guard enabled else { return ColorTokens.Text.primary.opacity(0.2) }
        switch outcome?.lowercased() {
        case "succeeded": return colored ? ExplorerSidebarPalette.jobs : ColorTokens.Status.success
        case "failed": return ColorTokens.Status.error
        case "in progress": return ColorTokens.Status.warning
        case "retry": return ColorTokens.Status.warning
        case "canceled": return ColorTokens.Text.primary.opacity(0.3)
        default: return colored ? ExplorerSidebarPalette.jobs : ColorTokens.Text.primary.opacity(0.2)
        }
    }
}
