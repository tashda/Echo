import SwiftUI

struct JobListView: View {
    var viewModel: JobQueueViewModel
    let notificationEngine: NotificationEngine?
    var permissions: (any DatabasePermissionProviding)?
    var onNewJob: (() -> Void)?
    @State private var tableSelection: Set<String> = []
    @State private var sortOrder: [KeyPathComparator<JobQueueViewModel.JobRow>] = [
        .init(\.name, order: .forward)
    ]

    private var sortedJobs: [JobQueueViewModel.JobRow] {
        viewModel.jobs.sorted(using: sortOrder)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Jobs").font(TypographyTokens.headline)
                Spacer()
            }
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.xxs2)

            Table(of: JobQueueViewModel.JobRow.self, selection: $tableSelection, sortOrder: $sortOrder) {
                TableColumn("Enabled", value: \.enabledSortKey) { job in
                    if viewModel.runningJobNames.contains(job.name) {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: job.enabled ? "checkmark.circle.fill" : "slash.circle")
                            .foregroundStyle(job.enabled ? ColorTokens.Status.success : ColorTokens.Text.secondary)
                    }
                }.width(28)
                TableColumn("Name", value: \.name) { job in
                    Text(job.name)
                        .font(TypographyTokens.Table.name)
                }
                TableColumn("Owner", value: \.ownerSortKey) { job in
                    Text(job.owner ?? "\u{2014}")
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(job.owner == nil ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
                }
                TableColumn("Category", value: \.categorySortKey) { job in
                    Text(job.category ?? "\u{2014}")
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(job.category == nil ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
                }
                TableColumn("Status", value: \.statusSortKey) { job in
                    let isRunning = viewModel.runningJobNames.contains(job.name)
                    Text(isRunning ? "Running" : "Idle")
                        .font(TypographyTokens.Table.status)
                        .foregroundStyle(isRunning ? ColorTokens.Status.warning : ColorTokens.Text.tertiary)
                }
                TableColumn("Last Run", value: \.lastRunDateSortKey) { job in
                    Text(job.lastRunDate ?? "\u{2014}")
                        .font(TypographyTokens.Table.date)
                        .foregroundStyle(job.lastRunDate == nil ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
                }
                TableColumn("Last Outcome", value: \.outcomeSortKey) { job in
                    Text(job.lastOutcome ?? "\u{2014}")
                        .font(TypographyTokens.Table.status)
                        .foregroundStyle(jobOutcomeColor(job.lastOutcome))
                }
                TableColumn("Next Run", value: \.nextRunSortKey) { job in
                    Text(job.nextRun ?? "—")
                        .font(TypographyTokens.Table.date)
                        .foregroundStyle(job.nextRun == nil ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
                }
            } rows: {
                ForEach(sortedJobs) { job in TableRow(job) }
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .tableColumnAutoResize()
            .contextMenu(forSelectionType: String.self) { items in
                if let id = items.first {
                    let jobIsRunning = viewModel.jobs.first(where: { $0.id == id }).map { viewModel.runningJobNames.contains($0.name) } ?? false

                    if !jobIsRunning {
                        Button("Start Job") {
                            Task {
                                viewModel.selectedJobID = id
                                let jobName = viewModel.jobs.first(where: { $0.id == id })?.name ?? "Job"
                                await viewModel.startSelectedJob()
                                if viewModel.errorMessage == nil {
                                    notificationEngine?.post(.jobStarted(name: jobName))
                                }
                            }
                        }
                        .disabled(!(permissions?.canManageAgent ?? true))
                    }
                    if jobIsRunning {
                        Button("Stop Job") {
                            Task {
                                viewModel.selectedJobID = id
                                let jobName = viewModel.jobs.first(where: { $0.id == id })?.name ?? "Job"
                                await viewModel.stopSelectedJob()
                                if viewModel.errorMessage == nil {
                                    notificationEngine?.post(.jobStopped(name: jobName))
                                }
                            }
                        }
                        .disabled(!(permissions?.canManageAgent ?? true))
                    }
                    Divider()
                    Button("Enable Job") { Task { viewModel.selectedJobID = id; await viewModel.setSelectedJobEnabled(true) } }
                        .disabled(!(permissions?.canManageAgent ?? true))
                    Button("Disable Job") { Task { viewModel.selectedJobID = id; await viewModel.setSelectedJobEnabled(false) } }
                        .disabled(!(permissions?.canManageAgent ?? true))
                } else {
                    // Empty space context menu
                    Button("New Job") { onNewJob?() }
                        .disabled(!(permissions?.canManageAgent ?? true))
                    Button("Refresh Jobs") { Task { await viewModel.reloadJobs() } }
                }
            }
            .onChange(of: tableSelection) { _, newValue in
                let newID = newValue.first
                if viewModel.selectedJobID != newID {
                    viewModel.selectedJobID = newID
                }
            }
            .onChange(of: viewModel.selectedJobID) { _, newID in
                let expected: Set<String> = newID.map { [$0] } ?? []
                if tableSelection != expected {
                    tableSelection = expected
                }
            }
            .onAppear {
                if let id = viewModel.selectedJobID {
                    tableSelection = [id]
                }
            }
        }
    }

    private func jobOutcomeColor(_ outcome: String?) -> Color {
        switch outcome {
        case "Succeeded": return ColorTokens.Status.success
        case "Failed": return ColorTokens.Status.error
        case "In Progress": return ColorTokens.Status.warning
        case nil: return ColorTokens.Text.tertiary
        default: return ColorTokens.Text.secondary
        }
    }
}
