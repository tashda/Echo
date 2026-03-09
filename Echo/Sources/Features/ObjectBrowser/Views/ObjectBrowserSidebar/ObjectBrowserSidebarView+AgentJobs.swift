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

        VStack(alignment: .leading, spacing: 0) {
            // Section header — matches folderHeaderRow style
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.agentJobsExpandedBySession[connID] = !isExpanded
                }
                if !isExpanded && jobs.isEmpty && !isLoading {
                    loadAgentJobs(session: session)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(SidebarRowConstants.chevronFont)
                        .foregroundStyle(.tertiary)
                        .frame(width: SidebarRowConstants.chevronWidth)

                    Image(systemName: "gearshape.2")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: SidebarRowConstants.iconFrame)

                    Text("SQL Server Agent")
                        .font(TypographyTokens.standard)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if !jobs.isEmpty {
                        Text("\(jobs.count)")
                            .font(TypographyTokens.label)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer(minLength: 4)
                }
                .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
                .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                agentJobsContent(session: session, jobs: jobs, isLoading: isLoading)
                    .padding(.leading, SidebarRowConstants.indentStep)
            }
        }
    }

    @ViewBuilder
    private func agentJobsContent(session: ConnectionSession, jobs: [ObjectBrowserSidebarViewModel.AgentJobItem], isLoading: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Agent Jobs Overview button
            Button {
                environmentState.openJobQueueTab(for: session)
            } label: {
                HStack(spacing: 8) {
                    Spacer().frame(width: SidebarRowConstants.chevronWidth)

                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: SidebarRowConstants.iconFrame)

                    Text("Agent Jobs Overview")
                        .font(TypographyTokens.standard)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 4)
                }
                .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
                .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isLoading {
                HStack(spacing: 8) {
                    Spacer().frame(width: SidebarRowConstants.chevronWidth)
                    ProgressView()
                        .controlSize(.mini)
                    Text("Loading jobs\u{2026}")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
                .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
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
                HStack(spacing: 8) {
                    Spacer().frame(width: SidebarRowConstants.chevronWidth)

                    Image(systemName: "plus.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .frame(width: SidebarRowConstants.iconFrame)

                    Text("New Job\u{2026}")
                        .font(TypographyTokens.standard)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)

                    Spacer(minLength: 4)
                }
                .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
                .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func agentJobRow(job: ObjectBrowserSidebarViewModel.AgentJobItem, session: ConnectionSession) -> some View {
        Button {
            environmentState.openJobQueueTab(for: session, selectJobID: job.name)
        } label: {
            HStack(spacing: 8) {
                Spacer().frame(width: SidebarRowConstants.chevronWidth)

                Image(systemName: job.enabled ? "checkmark.circle.fill" : "slash.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(job.enabled ? agentJobStatusColor(job.lastOutcome, enabled: true) : .secondary)
                    .frame(width: SidebarRowConstants.iconFrame)

                Text(job.name)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(job.enabled ? .primary : .secondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if !job.enabled {
                    Text("Disabled")
                        .font(TypographyTokens.label)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
            .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open in Job Management") {
                environmentState.openJobQueueTab(for: session, selectJobID: job.name)
            }
        }
    }

    private func agentJobStatusColor(_ outcome: String?, enabled: Bool) -> Color {
        guard enabled else { return Color.primary.opacity(0.2) }
        switch outcome?.lowercased() {
        case "succeeded": return .green
        case "failed": return .red
        case "in progress": return .orange
        case "retry": return .yellow
        case "canceled": return Color.primary.opacity(0.3)
        default: return Color.primary.opacity(0.2)
        }
    }

    // MARK: - Data Loading

    func loadAgentJobs(session: ConnectionSession) {
        let connID = session.connection.id
        guard let mssql = session.session as? MSSQLSession else { return }
        viewModel.agentJobsLoadingBySession[connID] = true

        Task {
            do {
                let agent = mssql.makeAgentClient()
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
                    let agent = mssql.makeAgentClient()
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
