import SwiftUI
import HatchCore

/// The Log (decisions N2, B5): every Hatch action with its GitHub sync result, a failed filter and Retry.
struct LogView: View {
    @EnvironmentObject var state: AppState
    @State private var failedOnly = false

    private var ops: [SyncOp] {
        let result: [SyncOp]?
        if failedOnly {
            result = try? state.store.syncLog(state: "failed", limit: 300)
        } else {
            result = try? state.store.syncLog(limit: 300)
        }
        return result ?? []
    }

    private func ticketLabel(_ id: Int?) -> String {
        guard let id else { return "" }
        let t: Ticket? = try? state.store.ticket(id: id)
        return t?.displayNumber ?? "#\(id)"
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbarRow
            Divider()
            let list = ops
            if list.isEmpty {
                HXEmpty(symbol: "list.bullet.rectangle", title: failedOnly ? "Nothing failed" : "Nothing logged yet",
                        detail: "Every change Hatch makes is recorded here with its result on GitHub.")
            } else {
                List {
                    ForEach(list) { op in row(op) }
                }
            }
        }
    }

    private var toolbarRow: some View {
        HStack(spacing: 12) {
            HXHeader(title: "Log", subtitle: "\(state.syncSummary.pending) waiting, \(state.syncSummary.failed) failed")
            Spacer()
            Toggle("Failed only", isOn: $failedOnly).toggleStyle(.checkbox)
            Button("Retry all failed") {
                state.perform("Retry") { try state.store.retryFailed() }
            }
            .disabled(state.syncSummary.failed == 0)
        }
        .padding(12)
    }

    private func turn(for op: SyncOp) -> Turn {
        switch op.state {
        case "done": return .finished
        case "failed": return .you
        default: return .hatch
        }
    }

    private func stateName(_ op: SyncOp) -> String {
        switch op.state {
        case "done": return "Synced"
        case "failed": return "Failed"
        default: return "Waiting"
        }
    }

    private func row(_ op: SyncOp) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(op.at.formatted(date: .omitted, time: .standard)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(op.op).font(.callout.monospaced()).frame(width: 150, alignment: .leading)
            Text(ticketLabel(op.ticketId)).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
            HXChip(text: stateName(op), turn: turn(for: op))
            if op.attempt > 0 { Text("attempt \(op.attempt)").font(.caption).foregroundStyle(.secondary) }
            if let error = op.error, !error.isEmpty {
                Text(error).font(.caption).foregroundStyle(Theme.critical).lineLimit(2).textSelection(.enabled)
            }
            Spacer()
            if op.state == "failed" || (op.state == "pending" && op.error != nil) {
                Button("Retry") { state.perform("Retry") { try state.store.retrySync(op.id) } }
            }
        }
        .padding(.vertical, 2)
    }
}
