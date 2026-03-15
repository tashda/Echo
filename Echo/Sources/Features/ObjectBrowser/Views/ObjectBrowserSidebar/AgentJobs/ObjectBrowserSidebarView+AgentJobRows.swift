import SwiftUI
import SQLServerKit

// MARK: - Agent Job Row Views

extension ObjectBrowserSidebarView {

    @ViewBuilder
    func agentJobsContent(session: ConnectionSession, jobs: [ObjectBrowserSidebarViewModel.AgentJobItem], isLoading: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func agentJobsOverviewButton(session: ConnectionSession) -> some View {
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

    func agentJobsLoadingIndicator() -> some View {
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

    func newJobButton(session: ConnectionSession) -> some View {
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

    func agentJobRow(job: ObjectBrowserSidebarViewModel.AgentJobItem, session: ConnectionSession) -> some View {
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
