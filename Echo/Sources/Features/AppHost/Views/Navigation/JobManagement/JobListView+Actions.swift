import SwiftUI

extension JobListView {
    private var selectedJob: JobQueueViewModel.JobRow? {
        viewModel.jobs.first { $0.id == viewModel.selectedJobID }
    }

    /// Round 37.5 (the owner's answer): New Job is the tab's special button in the window toolbar;
    /// Start or Stop for the selected job and Refresh are its group. The Jobs header keeps ⋯.
    var toolbarSpecial: TabToolbarItem {
        TabToolbarItem(id: "newJob", title: "New Job", symbol: "plus", isDisabled: !canManage) { onNewJob?() }
    }

    var toolbarGroups: [[TabToolbarItem]] {
        let isRunning = selectedJob.map { viewModel.listStatus(for: $0).isRunning } ?? false
        let startStop = isRunning
            ? TabToolbarItem(id: "stopJob", title: selectedJob.map { "Stop \($0.name)" } ?? "Stop Job", symbol: "stop.fill",
                             isDisabled: !canManage) { stopSelected() }
            : TabToolbarItem(id: "startJob", title: selectedJob.map { "Start \($0.name)" } ?? "Start Job", symbol: "play.fill",
                             isDisabled: !canManage || selectedJob == nil) { startSelected() }
        // Open in New Window is its own toolbar group (the owner, 2026-10-01), not in this one.
        return [[startStop], [.refresh { Task { await viewModel.reloadJobs() } }]]
    }

    /// Reads the selection when pressed, so the toolbar never acts on a job selected earlier.
    private func startSelected() { if let id = viewModel.selectedJobID { start(jobID: id) } }
    private func stopSelected() { if let id = viewModel.selectedJobID { stop(jobID: id) } }

    /// JA1's other actions in ⋯; New Job and Start/Stop are in the window toolbar (round 37.5).
    @ViewBuilder
    var headerActions: some View {
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
