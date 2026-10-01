import SwiftUI
import SQLServerKit

/// The Jobs pane (round 33): the full height of the tab's left side, one pane header with ⋯, and
/// the columns Status, Name, Last run and Next run. New Job and Start/Stop are in the window
/// toolbar (round 37.5).
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

    @State var showAlertSheet = false
    @State var showProxySheet = false
    @State var showCategorySheet = false
    @State var showNewAlertSheet = false
    @State var editingAlert: JobQueueViewModel.AlertRow?
    @State var editingProxy: JobQueueViewModel.ProxyRow?
    @State var pendingDeleteAlertName: String?
    @State var showDeleteAlertAlert = false

    var canManage: Bool { permissions?.canManageAgent ?? true }

    var body: some View {
        VStack(spacing: SpacingTokens.none) {
            PaneHeader("Jobs", count: viewModel.jobs.count) { headerActions }

            Table(of: JobQueueViewModel.JobRow.self, selection: $tableSelection, sortOrder: $sortOrder) {
                TableColumn("Status", value: \.enabledSortKey) { job in
                    JobStatusSymbol(status: viewModel.listStatus(for: job))
                }.width(LayoutTokens.AgentJobs.statusColumnWidth)
                TableColumn("Name", value: \.name) { job in
                    Text(job.name)
                        .font(TypographyTokens.Table.name)
                        .foregroundStyle(job.enabled ? ColorTokens.Text.primary : ColorTokens.Text.tertiary)
                }
                TableColumn("Last Run", value: \.lastRunDateSortKey) { job in
                    lastRunCell(job)
                }
                TableColumn("Next Run", value: \.nextRunSortKey) { job in
                    Text(job.enabled ? job.nextRun ?? "\u{2014}" : "Disabled")
                        .font(TypographyTokens.Table.date)
                        .foregroundStyle(job.enabled && job.nextRun != nil ? ColorTokens.Text.secondary : ColorTokens.Text.tertiary)
                }
            } rows: {
                ForEach(sortedJobs) { job in TableRow(job) }
            }
            // ER1: the list ends where its rows end; no stripes below the last row.
            .tableStyle(.inset(alternatesRowBackgrounds: false))
            .tableColumnAutoResize()
            .contextMenu(forSelectionType: String.self) { items in
                if let id = items.first {
                    jobMenuItems(jobID: id)
                } else {
                    Button { onNewJob?() } label: { Label("New Job", systemImage: "plus") }
                        .disabled(!canManage)
                    Button { Task { await viewModel.reloadJobs() } } label: { Label("Refresh Jobs", systemImage: "arrow.clockwise") }
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
            .background(alertSheets)
        }
        .tabToolbar(special: toolbarSpecial, groups: toolbarGroups)
    }

    /// JR1: a running job shows how long it has been running, counting up, in Last Run.
    @ViewBuilder
    private func lastRunCell(_ job: JobQueueViewModel.JobRow) -> some View {
        switch viewModel.listStatus(for: job) {
        case .running(let since?):
            Text(since, style: .timer)
                .font(TypographyTokens.Table.date.monospacedDigit())
                .foregroundStyle(ColorTokens.Status.warning)
        case .running(nil):
            Text("Running")
                .font(TypographyTokens.Table.date)
                .foregroundStyle(ColorTokens.Status.warning)
        case .failed:
            Text(job.lastRunDate ?? "\u{2014}")
                .font(TypographyTokens.Table.date)
                .foregroundStyle(ColorTokens.Status.error)
        case .ready, .disabled:
            Text(job.lastRunDate ?? "\u{2014}")
                .font(TypographyTokens.Table.date)
                .foregroundStyle(job.lastRunDate == nil ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
        }
    }
}
