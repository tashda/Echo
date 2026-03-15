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
                Button {
                    environmentState.openJobQueueTab(for: session)
                } label: {
                    HStack(spacing: SpacingTokens.xs) {
                        Spacer().frame(width: SidebarRowConstants.chevronWidth)

                        Image(systemName: "list.bullet.rectangle")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ExplorerSidebarPalette.jobs)
                            .frame(width: SidebarRowConstants.iconFrame)

                        Text("Agent Jobs Overview")
                            .font(TypographyTokens.standard)
                            .foregroundStyle(ColorTokens.Text.primary)
                            .lineLimit(1)

                        Spacer(minLength: 4)
                    }
                    .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
                    .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if isLoading {
                sidebarListRow(leading: baseIndent + SidebarRowConstants.indentStep) {
                    HStack(spacing: SpacingTokens.xs) {
                        Spacer().frame(width: SidebarRowConstants.chevronWidth)
                        ProgressView()
                            .controlSize(.mini)
                        Text("Loading jobs\u{2026}")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                    .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
                    .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                Button {
                    viewModel.newJobSessionID = session.connection.id
                    viewModel.showNewJobSheet = true
                } label: {
                    HStack(spacing: SpacingTokens.xs) {
                        Spacer().frame(width: SidebarRowConstants.chevronWidth)

                        Image(systemName: "plus.circle")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                            .frame(width: SidebarRowConstants.iconFrame)

                        Text("New Job\u{2026}")
                            .font(TypographyTokens.standard)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                            .lineLimit(1)

                        Spacer(minLength: 4)
                    }
                    .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
                    .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func agentJobsHeaderRow(session: ConnectionSession, isExpanded: Bool, jobs: [ObjectBrowserSidebarViewModel.AgentJobItem]) -> some View {
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

    @ViewBuilder
    private func agentJobsContent(session: ConnectionSession, jobs: [ObjectBrowserSidebarViewModel.AgentJobItem], isLoading: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                environmentState.openJobQueueTab(for: session)
            } label: {
                HStack(spacing: SpacingTokens.xs) {
                    Spacer().frame(width: SidebarRowConstants.chevronWidth)

                    Image(systemName: "list.bullet.rectangle")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ExplorerSidebarPalette.jobs)
                        .frame(width: SidebarRowConstants.iconFrame)

                    Text("Agent Jobs Overview")
                        .font(TypographyTokens.standard)
                        .foregroundStyle(ColorTokens.Text.primary)
                        .lineLimit(1)

                    Spacer(minLength: 4)
                }
                .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
                .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isLoading {
                HStack(spacing: SpacingTokens.xs) {
                    Spacer().frame(width: SidebarRowConstants.chevronWidth)
                    ProgressView()
                        .controlSize(.mini)
                    Text("Loading jobs\u{2026}")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
                .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if !jobs.isEmpty {
                ForEach(jobs) { job in
                    agentJobRow(job: job, session: session)
                }
            }

            // New Job button — at bottom of list
            Button {
                viewModel.newJobSessionID = session.connection.id
                viewModel.showNewJobSheet = true
            } label: {
                HStack(spacing: SpacingTokens.xs) {
                    Spacer().frame(width: SidebarRowConstants.chevronWidth)

                    Image(systemName: "plus.circle")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .frame(width: SidebarRowConstants.iconFrame)

                    Text("New Job\u{2026}")
                        .font(TypographyTokens.standard)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .lineLimit(1)

                    Spacer(minLength: 4)
                }
                .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
                .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func agentJobRow(job: ObjectBrowserSidebarViewModel.AgentJobItem, session: ConnectionSession) -> some View {
        Button {
            environmentState.openJobQueueTab(for: session, selectJobID: job.name)
        } label: {
            HStack(spacing: SpacingTokens.xs) {
                Spacer().frame(width: SidebarRowConstants.chevronWidth)

                Image(systemName: "clock")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(job.enabled ? agentJobStatusColor(job.lastOutcome, enabled: true) : ColorTokens.Text.quaternary)
                    .frame(width: SidebarRowConstants.iconFrame)

                Text(job.name)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(job.enabled ? .primary : .secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 4)

                if !job.enabled {
                    Text("Disabled")
                        .font(TypographyTokens.label)
                        .foregroundStyle(ColorTokens.Text.quaternary)
                }
            }
            .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
            .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                environmentState.openJobQueueTab(for: session, selectJobID: job.name)
            } label: {
                Label("Open in Job Management", systemImage: "list.bullet.rectangle")
            }
        }
    }

    private func agentJobStatusColor(_ outcome: String?, enabled: Bool) -> Color {
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
