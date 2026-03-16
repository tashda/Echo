import SwiftUI
import SQLServerKit

struct MSSQLActivityWaits: View {
    let waits: [SQLServerWaitStatDelta]
    @Binding var sortOrder: [KeyPathComparator<SQLServerWaitStatDelta>]
    @Binding var selection: Set<SQLServerWaitStatDelta.ID>
    var onDoubleClick: (() -> Void)?

    private var sortedWaits: [SQLServerWaitStatDelta] {
        waits.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedWaits, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Wait Type", value: \.waitType) {
                Text($0.waitType)
                    .font(TypographyTokens.detail)
                    .lineLimit(1)
            }.width(min: 150, ideal: 220)

            TableColumn("Wait Time", value: \.waitTimeMsDelta) {
                Text(formatMs($0.waitTimeMsDelta))
                    .font(TypographyTokens.detail.monospacedDigit())
                    .foregroundStyle($0.waitTimeMsDelta > 1000 ? ColorTokens.Status.error : $0.waitTimeMsDelta > 100 ? ColorTokens.Status.warning : ColorTokens.Text.primary)
            }.width(min: 70, ideal: 80)

            TableColumn("Signal Wait", value: \.signalWaitTimeMsDelta) {
                Text(formatMs($0.signalWaitTimeMsDelta))
                    .font(TypographyTokens.detail.monospacedDigit())
                    .foregroundStyle(ColorTokens.Text.secondary)
            }.width(min: 70, ideal: 80)

            TableColumn("Tasks", value: \.waitingTasksCountDelta) {
                Text("\($0.waitingTasksCountDelta)")
                    .font(TypographyTokens.detail.monospacedDigit())
            }.width(min: 50, ideal: 60)

            TableColumn("Avg Wait") { wait in
                let avg = wait.waitingTasksCountDelta > 0 ? wait.waitTimeMsDelta / wait.waitingTasksCountDelta : 0
                Text(formatMs(avg))
                    .font(TypographyTokens.detail.monospacedDigit())
                    .foregroundStyle(ColorTokens.Text.secondary)
            }.width(min: 60, ideal: 70)

            TableColumn("Signal %") { wait in
                let pct = wait.waitTimeMsDelta > 0 ? Double(wait.signalWaitTimeMsDelta) / Double(wait.waitTimeMsDelta) * 100 : 0
                Text(String(format: "%.0f%%", pct))
                    .font(TypographyTokens.detail.monospacedDigit())
                    .foregroundStyle(pct > 50 ? ColorTokens.Status.warning : ColorTokens.Text.tertiary)
                    .help("High signal wait % indicates CPU contention")
            }.width(min: 50, ideal: 60)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: SQLServerWaitStatDelta.ID.self) { _ in
        } primaryAction: { _ in
            onDoubleClick?()
        }
    }

    private func formatMs(_ ms: Int) -> String {
        if ms >= 60_000 { return String(format: "%.1fs", Double(ms) / 1000) }
        return "\(ms)ms"
    }
}
