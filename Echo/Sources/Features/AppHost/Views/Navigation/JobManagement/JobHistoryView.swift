import SwiftUI

struct JobHistoryView: View {
    @ObservedObject var viewModel: JobQueueViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("History").font(.headline)
                Spacer()
            }
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.xxs2)

            Table(of: JobQueueViewModel.HistoryRow.self) {
                TableColumn("Job") { h in Text(h.jobName) }
                TableColumn("Step") { h in Text("\(h.stepId)") }.width(44)
                TableColumn("Status") { h in Text(jobStatusLabel(h.status)).foregroundStyle(colorForStatus(h.status)) }
                TableColumn("Run Date") { h in Text(formatAgentDate(h.runDate, h.runTime)) }
                TableColumn("Duration") { h in Text(formatDuration(h.runDuration)) }
                TableColumn("Message") { h in Text(h.message).lineLimit(1).truncationMode(.tail) }
            } rows: {
                ForEach(viewModel.history) { h in TableRow(h) }
            }
        }
    }

    // MARK: - Utilities

    private func formatAgentDate(_ dateInt: Int, _ timeInt: Int) -> String {
        guard dateInt > 0 else { return "—" }
        let yyyy = dateInt / 10000
        let mm = (dateInt / 100) % 100
        let dd = dateInt % 100
        let hh = timeInt / 10000
        let mi = (timeInt / 100) % 100
        let ss = timeInt % 100
        let comps = DateComponents(year: yyyy, month: mm, day: dd, hour: hh, minute: mi, second: ss)
        if let date = Calendar(identifier: .gregorian).date(from: comps) {
            let fmt = DateFormatter()
            fmt.dateStyle = .medium
            fmt.timeStyle = .medium
            return fmt.string(from: date)
        }
        return "—"
    }

    private func jobStatusLabel(_ status: Int) -> String {
        switch status { case 0: return "Failed"; case 1: return "Succeeded"; case 2: return "Retry"; case 3: return "Canceled"; case 4: return "In Progress"; default: return "?" }
    }

    private func colorForStatus(_ status: Int) -> Color {
        switch status { case 1: return .green; case 0: return .red; case 4: return .yellow; default: return .secondary }
    }

    private func formatDuration(_ runDuration: Int) -> String {
        let hours = runDuration / 10000
        let minutes = (runDuration / 100) % 100
        let seconds = runDuration % 100
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
