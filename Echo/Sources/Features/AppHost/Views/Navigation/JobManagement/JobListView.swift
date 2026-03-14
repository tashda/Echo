import SwiftUI

struct JobListView: View {
    @ObservedObject var viewModel: JobQueueViewModel
    let notificationEngine: NotificationEngine?
    @State private var tableSelection: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Jobs").font(TypographyTokens.headline)
                Spacer()
                if viewModel.isLoadingJobs { ProgressView().controlSize(.small) }
                Button {
                    Task { await viewModel.reloadJobs() }
                } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.xxs2)

            Table(of: JobQueueViewModel.JobRow.self, selection: $tableSelection) {
                TableColumn("Enabled") { job in
                    if viewModel.runningJobNames.contains(job.name) {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: job.enabled ? "checkmark.circle.fill" : "slash.circle")
                            .foregroundStyle(job.enabled ? ColorTokens.Status.success : ColorTokens.Text.secondary)
                    }
                }.width(28)
                TableColumn("Name", value: \.name)
                TableColumn("Owner") { job in Text(job.owner ?? "—").foregroundStyle(job.owner == nil ? ColorTokens.Text.secondary : ColorTokens.Text.primary) }
                TableColumn("Category") { job in Text(job.category ?? "—").foregroundStyle(job.category == nil ? ColorTokens.Text.secondary : ColorTokens.Text.primary) }
                TableColumn("Last Outcome") { job in Text(job.lastOutcome ?? "—").foregroundStyle(job.lastOutcome == nil ? ColorTokens.Text.secondary : ColorTokens.Text.primary) }
                TableColumn("Next Run") { job in Text(job.nextRun ?? "—").foregroundStyle(job.nextRun == nil ? ColorTokens.Text.secondary : ColorTokens.Text.primary) }
            } rows: {
                ForEach(viewModel.jobs) { job in TableRow(job) }
            }
            .contextMenu(forSelectionType: String.self) { items in
                if let id = items.first {
                    let jobIsRunning = viewModel.jobs.first(where: { $0.id == id }).map { viewModel.runningJobNames.contains($0.name) } ?? false

                    if !jobIsRunning {
                        Button("Start Job") {
                            Task {
                                viewModel.selectedJobID = id
                                await viewModel.startSelectedJob()
                                if viewModel.errorMessage == nil {
                                    notificationEngine?.post(category: .jobStarted, message: "Job started")
                                }
                            }
                        }
                    }
                    if jobIsRunning {
                        Button("Stop Job") {
                            Task {
                                viewModel.selectedJobID = id
                                await viewModel.stopSelectedJob()
                                if viewModel.errorMessage == nil {
                                    notificationEngine?.post(category: .jobStopped, message: "Job stopped")
                                }
                            }
                        }
                    }
                    Divider()
                    Button("Enable") { Task { viewModel.selectedJobID = id; await viewModel.setSelectedJobEnabled(true) } }
                    Button("Disable") { Task { viewModel.selectedJobID = id; await viewModel.setSelectedJobEnabled(false) } }
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
}
