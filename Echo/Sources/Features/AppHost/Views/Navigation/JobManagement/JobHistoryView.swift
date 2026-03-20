import SwiftUI

struct JobHistoryView: View {
    var viewModel: JobQueueViewModel
    @State private var sortOrder: [KeyPathComparator<JobQueueViewModel.HistoryRow>] = [
        .init(\.runDateTimeSortKey, order: .reverse)
    ]

    private var sortedHistory: [JobQueueViewModel.HistoryRow] {
        viewModel.history.sorted(using: sortOrder)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("History").font(TypographyTokens.headline)
                Spacer()
            }
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.xxs2)

            Table(of: JobQueueViewModel.HistoryRow.self, selection: Binding(
                get: { viewModel.selectedHistoryRowID.flatMap { Set([$0]) } ?? [] },
                set: { viewModel.selectedHistoryRowID = $0.first }
            ), sortOrder: $sortOrder) {
                TableColumn("Job", value: \.jobName) { h in
                    Text(h.jobName)
                        .font(TypographyTokens.Table.name)
                }
                TableColumn("Step ID", value: \.stepId) { h in
                    Text("\(h.stepId)")
                        .font(TypographyTokens.Table.numeric)
                }.width(52)
                TableColumn("Step Name", value: \.stepName) { h in
                    Text(h.stepName)
                        .font(TypographyTokens.Table.name)
                        .foregroundStyle(h.stepId == 0 ? ColorTokens.Text.secondary : ColorTokens.Text.primary)
                }
                TableColumn("Status", value: \.statusLabel) { h in
                    Text(h.statusLabel)
                        .font(TypographyTokens.Table.status)
                        .foregroundStyle(colorForStatus(h.status))
                }
                TableColumn("Run Date", value: \.runDateTimeSortKey) { h in
                    Text(formatAgentDate(h.runDate, h.runTime))
                        .font(TypographyTokens.Table.date)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                TableColumn("Duration", value: \.runDuration) { h in
                    Text(formatDuration(h.runDuration))
                        .font(TypographyTokens.Table.numeric)
                }
                TableColumn("Message", value: \.message) { h in
                    Text(h.message)
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            } rows: {
                ForEach(sortedHistory) { h in TableRow(h) }
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
        }
    }

    // MARK: - Utilities

    private func formatAgentDate(_ dateInt: Int, _ timeInt: Int) -> String {
        guard dateInt > 0 else { return "\u{2014}" }
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
        return "\u{2014}"
    }

    private func colorForStatus(_ status: Int) -> Color {
        switch status { case 1: return ColorTokens.Status.success; case 0: return ColorTokens.Status.error; case 4: return ColorTokens.Status.warning; default: return ColorTokens.Text.secondary }
    }

    private func formatDuration(_ runDuration: Int) -> String {
        let hours = runDuration / 10000
        let minutes = (runDuration / 100) % 100
        let seconds = runDuration % 100
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
