import SwiftUI

struct JobListView: View {
    @ObservedObject var viewModel: JobQueueViewModel
    @Binding var selection: Set<String>

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

            Table(of: JobQueueViewModel.JobRow.self, selection: Binding(get: {
                if let id = viewModel.selectedJobID { return Set([id]) } else { return Set<String>() }
            }, set: { newSel in
                viewModel.selectedJobID = newSel.first
                selection = newSel
            })) {
                TableColumn("Enabled") { job in
                    Image(systemName: job.enabled ? "checkmark.circle.fill" : "slash.circle")
                        .foregroundStyle(job.enabled ? .green : .secondary)
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
                    Button("Start Job") { Task { viewModel.selectedJobID = id; await viewModel.startSelectedJob() } }
                    Button("Stop Job") { Task { viewModel.selectedJobID = id; await viewModel.stopSelectedJob() } }
                    Divider()
                    Button("Enable") { Task { viewModel.selectedJobID = id; await viewModel.setSelectedJobEnabled(true) } }
                    Button("Disable") { Task { viewModel.selectedJobID = id; await viewModel.setSelectedJobEnabled(false) } }
                }
            }
        }
    }
}
