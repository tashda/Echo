import SwiftUI
import SQLServerKit

struct MSSQLActivityProcesses: View {
    let processes: [SQLServerProcessInfo]
    @Binding var sortOrder: [KeyPathComparator<SQLServerProcessInfo>]
    @Binding var selection: Set<SQLServerProcessInfo.ID>
    let onPopout: (String) -> Void
    let onKill: (Int) -> Void
    var onDoubleClick: (() -> Void)?

    private var sortedProcesses: [SQLServerProcessInfo] {
        processes.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedProcesses, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("ID", value: \.sessionId) {
                Text("\($0.sessionId)").font(TypographyTokens.Table.numeric)
            }.width(min: 40, max: 60)

            TableColumn("User", value: \.sortableLoginName) {
                Text($0.loginName ?? "")
                    .font(TypographyTokens.Table.name)
                    .foregroundStyle(($0.loginName ?? "").isEmpty ? ColorTokens.Text.secondary : ColorTokens.Text.primary)
            }.width(min: 80, ideal: 100)

            TableColumn("Wait", value: \.sortableWaitType) { proc in
                if let wait = proc.request?.waitType, !wait.isEmpty {
                    Text(wait)
                        .font(TypographyTokens.Table.category)
                        .foregroundStyle(ColorTokens.Status.warning)
                        .lineLimit(1)
                }
            }.width(min: 80, ideal: 100)

            TableColumn("Blocked By", value: \.sortableBlockedBy) { proc in
                if let blocker = proc.request?.blockingSessionId, blocker > 0 {
                    Text("SID \(blocker)")
                        .font(TypographyTokens.Table.status)
                        .foregroundStyle(ColorTokens.Status.error)
                }
            }.width(min: 60, ideal: 70)

            TableColumn("Command", value: \.sortableCommand) {
                if let sql = $0.request?.sqlText, !sql.isEmpty {
                    SQLQueryCell(sql: sql, onPopout: onPopout)
                } else {
                    Text($0.request?.command ?? "")
                        .font(TypographyTokens.Table.category)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            TableColumn("CPU", value: \.sortableCpuTime) {
                Text("\($0.sessionCpuTimeMs ?? 0)ms")
                    .font(TypographyTokens.Table.numeric)
            }.width(60)

            TableColumn("Memory", value: \.sortableMemory) {
                Text("\($0.memoryUsageKB ?? 0) KB")
                    .font(TypographyTokens.Table.numeric)
            }.width(70)

            TableColumn("Reads", value: \.sortableReads) {
                Text("\($0.sessionReads ?? 0)")
                    .font(TypographyTokens.Table.numeric)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }.width(60)

            TableColumn("Status", value: \.sortableStatus) {
                StatusBadge(text: $0.sessionStatus ?? "", isSystem: ($0.loginName ?? "").isEmpty)
            }.width(80)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: SQLServerProcessInfo.ID.self) { selection in
            if let id = selection.first, let process = processes.first(where: { $0.id == id }) {
                Button("Details") {
                    onDoubleClick?()
                }

                if process.request?.sqlText != nil {
                    Button("View SQL") {
                        if let sql = process.request?.sqlText { onPopout(sql) }
                    }
                }

                Divider()

                Button("Kill Process", role: .destructive) {
                    onKill(id)
                }
            }
        } primaryAction: { _ in
            onDoubleClick?()
        }
    }
}
