import SwiftUI
import SQLServerKit

extension ObjectBrowserSidebarView {

    // MARK: - SQL Server Agent Section

    @ViewBuilder
    func agentJobsSection(session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let isExpanded = viewModel.agentJobsExpandedBySession[connID] ?? false
        let jobs = viewModel.agentJobsBySession[connID] ?? []
        let isLoading = viewModel.agentJobsLoadingBySession[connID] ?? false

        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            folderHeaderRow(
                title: "Agent Jobs",
                icon: "clock",
                count: jobs.isEmpty ? nil : jobs.count,
                isExpanded: isExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.agentJobsExpandedBySession[connID] = !isExpanded
                }
                if !isExpanded && jobs.isEmpty && !isLoading {
                    loadAgentJobs(session: session)
                }
            }

            if isExpanded {
                agentJobsContent(session: session, jobs: jobs, isLoading: isLoading)
                    .padding(.leading, SidebarRowConstants.indentStep)
            }
        }
    }

    // MARK: - Flat List Row Agent Jobs

    @ViewBuilder
    func agentJobsListRows(session: ConnectionSession, baseIndent: CGFloat) -> some View {
        let connID = session.connection.id
        let isExpanded = viewModel.agentJobsExpandedBySession[connID] ?? false
        let jobs = viewModel.agentJobsBySession[connID] ?? []
        let isLoading = viewModel.agentJobsLoadingBySession[connID] ?? false

        sidebarListRow(leading: baseIndent) {
            agentJobsHeaderRow(session: session, isExpanded: isExpanded, jobs: jobs)
        }

        if isExpanded {
            // Agent Jobs Overview link
            sidebarListRow(leading: baseIndent + SidebarRowConstants.indentStep) {
                agentJobsOverviewButton(session: session)
            }

            if isLoading {
                sidebarListRow(leading: baseIndent + SidebarRowConstants.indentStep) {
                    agentJobsLoadingIndicator()
                }
            } else {
                ForEach(jobs) { job in
                    sidebarListRow(leading: baseIndent + SidebarRowConstants.indentStep) {
                        agentJobRow(job: job, session: session)
                    }
                }
            }

            // New Job button
            sidebarListRow(leading: baseIndent + SidebarRowConstants.indentStep) {
                newJobButton(session: session)
            }
        }
    }

    func agentJobsHeaderRow(session: ConnectionSession, isExpanded: Bool, jobs: [ObjectBrowserSidebarViewModel.AgentJobItem]) -> some View {
        let connID = session.connection.id
        let isLoading = viewModel.agentJobsLoadingBySession[connID] ?? false

        return folderHeaderRow(
            title: "Agent Jobs",
            icon: "clock",
            count: jobs.isEmpty ? nil : jobs.count,
            isExpanded: isExpanded
        ) {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.agentJobsExpandedBySession[connID] = !isExpanded
            }
            if !isExpanded && jobs.isEmpty && !isLoading {
                loadAgentJobs(session: session)
            }
        }
    }

    // MARK: - Data Loading

    func loadAgentJobs(session: ConnectionSession) {
        let connID = session.connection.id
        guard let mssql = session.session as? MSSQLSession else { return }
        viewModel.agentJobsLoadingBySession[connID] = true

        Task {
            do {
                let agent = mssql.agent
                let detailed = try await agent.listJobsDetailed()
                let items = detailed.map { job in
                    ObjectBrowserSidebarViewModel.AgentJobItem(
                        id: job.jobId,
                        name: job.name,
                        enabled: job.enabled,
                        lastOutcome: job.lastRunOutcome
                    )
                }
                await MainActor.run {
                    viewModel.agentJobsBySession[connID] = items
                    viewModel.agentJobsLoadingBySession[connID] = false
                }
            } catch {
                // Fallback to basic API
                do {
                    let agent = mssql.agent
                    let basic = try await agent.listJobs()
                    let items = basic.map { job in
                        ObjectBrowserSidebarViewModel.AgentJobItem(
                            id: job.name,
                            name: job.name,
                            enabled: job.enabled,
                            lastOutcome: job.lastRunOutcome
                        )
                    }
                    await MainActor.run {
                        viewModel.agentJobsBySession[connID] = items
                        viewModel.agentJobsLoadingBySession[connID] = false
                    }
                } catch {
                    await MainActor.run {
                        viewModel.agentJobsLoadingBySession[connID] = false
                    }
                }
            }
        }
    }
}
