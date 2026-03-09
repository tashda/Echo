import SwiftUI

struct JobListView: View {
    @ObservedObject var viewModel: JobQueueViewModel
    let toastCoordinator: StatusToastCoordinator
    @State private var tableSelection: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Jobs").font(.headline)
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
                            .foregroundStyle(job.enabled ? .green : .secondary)
                    }
                }.width(28)
                TableColumn("Name", value: \.name)
                TableColumn("Owner") { job in Text(job.owner ?? "—").foregroundStyle(job.owner == nil ? .secondary : .primary) }
                TableColumn("Category") { job in Text(job.category ?? "—").foregroundStyle(job.category == nil ? .secondary : .primary) }
                TableColumn("Last Outcome") { job in Text(job.lastOutcome ?? "—").foregroundStyle(job.lastOutcome == nil ? .secondary : .primary) }
                TableColumn("Next Run") { job in Text(job.nextRun ?? "—").foregroundStyle(job.nextRun == nil ? .secondary : .primary) }
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
                                    toastCoordinator.show(icon: "play.fill", message: "Job started", style: .success)
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
                                    toastCoordinator.show(icon: "stop.fill", message: "Job stopped", style: .success)
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
