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
                Text("\($0.sessionId)").font(TypographyTokens.detail.monospacedDigit())
            }.width(min: 40, max: 60)

            TableColumn("User") {
                Text($0.loginName ?? "")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(($0.loginName ?? "").isEmpty ? ColorTokens.Text.secondary : ColorTokens.Text.primary)
            }.width(min: 80, ideal: 100)

            TableColumn("Status") {
                StatusBadge(text: $0.sessionStatus ?? "", isSystem: ($0.loginName ?? "").isEmpty)
            }.width(80)

            TableColumn("Wait") { proc in
                if let wait = proc.request?.waitType, !wait.isEmpty {
                    Text(wait)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Status.warning)
                        .lineLimit(1)
                }
            }.width(min: 80, ideal: 100)

            TableColumn("Blocked By") { proc in
                if let blocker = proc.request?.blockingSessionId, blocker > 0 {
                    Text("SID \(blocker)")
                        .font(TypographyTokens.detail.weight(.medium))
                        .foregroundStyle(ColorTokens.Status.error)
                }
            }.width(min: 60, ideal: 70)

            TableColumn("Command") {
                if let sql = $0.request?.sqlText, !sql.isEmpty {
                    SQLQueryCell(sql: sql, onPopout: onPopout)
                } else {
                    Text($0.request?.command ?? "")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }

            TableColumn("CPU") {
                Text("\($0.sessionCpuTimeMs ?? 0)ms")
                    .font(TypographyTokens.detail.monospacedDigit())
            }.width(60)

            TableColumn("Memory") {
                Text("\($0.memoryUsageKB ?? 0) KB")
                    .font(TypographyTokens.detail.monospacedDigit())
            }.width(70)

            TableColumn("Reads") {
                Text("\($0.sessionReads ?? 0)")
                    .font(TypographyTokens.detail.monospacedDigit())
                    .foregroundStyle(ColorTokens.Text.secondary)
            }.width(60)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: SQLServerProcessInfo.ID.self) { selection in
            if let id = selection.first, let process = processes.first(where: { $0.id == id }) {
                Button("Details") {
                    if let sql = process.request?.sqlText { onPopout(sql) }
                }
                .disabled(process.request?.sqlText == nil)

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
