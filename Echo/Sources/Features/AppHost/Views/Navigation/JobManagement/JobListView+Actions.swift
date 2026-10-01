import SwiftUI

extension JobListView {
    private var selectedJob: JobQueueViewModel.JobRow? {
        viewModel.jobs.first { $0.id == viewModel.selectedJobID }
    }

    /// JA1: New Job and Start/Stop on the Jobs header; everything else in ⋯ and the right-click menu.
    @ViewBuilder
    var headerActions: some View {
        Button { onNewJob?() } label: { Image(systemName: "plus") }
            .help("New Job")
            .disabled(!canManage)

        if let job = selectedJob, viewModel.listStatus(for: job).isRunning {
            Button { stop(jobID: job.id) } label: { Image(systemName: "stop.fill") }
                .help("Stop \(job.name)")
                .disabled(!canManage)
        } else {
            Button { if let id = selectedJob?.id { start(jobID: id) } } label: { Image(systemName: "play.fill") }
                .help(selectedJob.map { "Start \($0.name)" } ?? "Start Job")
                .disabled(!canManage || selectedJob == nil)
        }

        Menu {
            if let id = selectedJob?.id {
                Button { setEnabled(true, jobID: id) } label: { Label("Enable Job", systemImage: "checkmark.circle") }
                    .disabled(!canManage || selectedJob?.enabled == true)
                Button { setEnabled(false, jobID: id) } label: { Label("Disable Job", systemImage: "nosign") }
                    .disabled(!canManage || selectedJob?.enabled == false)
                Divider()
            }
            Button { showNewAlertSheet = true } label: { Label("New Alert", systemImage: "bell") }
            Button { showProxySheet = true } label: { Label("New Proxy", systemImage: "person.badge.key") }
            Divider()
            Button { showCategorySheet = true } label: { Label("Manage Categories", systemImage: "folder") }
            Divider()
            Button { Task { await viewModel.reloadJobs() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Agent management actions")
    }

    /// The right-click menu of one job.
    @ViewBuilder
    func jobMenuItems(jobID id: String) -> some View {
        let isRunning = viewModel.jobs.first { $0.id == id }.map { viewModel.listStatus(for: $0).isRunning } ?? false
        if isRunning {
            Button { stop(jobID: id) } label: { Label("Stop Job", systemImage: "stop.fill") }
                .disabled(!canManage)
        } else {
            Button { start(jobID: id) } label: { Label("Start Job", systemImage: "play.fill") }
                .disabled(!canManage)
        }
        Divider()
        Button { setEnabled(true, jobID: id) } label: { Label("Enable Job", systemImage: "checkmark.circle") }
            .disabled(!canManage)
        Button { setEnabled(false, jobID: id) } label: { Label("Disable Job", systemImage: "nosign") }
            .disabled(!canManage)
    }

    func start(jobID id: String) {
        Task {
            viewModel.selectedJobID = id
            let jobName = viewModel.jobs.first { $0.id == id }?.name ?? "Job"
            await viewModel.startSelectedJob()
            if viewModel.errorMessage == nil {
                notificationEngine?.post(.jobStarted(name: jobName))
            }
        }
    }

    func stop(jobID id: String) {
        Task {
            viewModel.selectedJobID = id
            let jobName = viewModel.jobs.first { $0.id == id }?.name ?? "Job"
            await viewModel.stopSelectedJob()
            if viewModel.errorMessage == nil {
                notificationEngine?.post(.jobStopped(name: jobName))
            }
        }
    }

    func setEnabled(_ enabled: Bool, jobID id: String) {
        Task {
            viewModel.selectedJobID = id
            await viewModel.setSelectedJobEnabled(enabled)
        }
    }
}
