import SwiftUI
import SQLServerKit

struct MSSQLActivityProcesses: View {
    let processes: [SQLServerProcessInfo]
    @Binding var sortOrder: [KeyPathComparator<SQLServerProcessInfo>]
    @Binding var selection: Set<SQLServerProcessInfo.ID>
    let onPopout: (String) -> Void
    let onKill: (Int) -> Void
    var canKill: Bool = true
    var onDoubleClick: (() -> Void)?

    @State private var showKillAlert = false
    @State private var pendingKillID: Int?

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
        .tableColumnAutoResize()
        .contextMenu(forSelectionType: SQLServerProcessInfo.ID.self) { selection in
            if let id = selection.first, let process = processes.first(where: { $0.id == id }) {
                Button {
                    onDoubleClick?()
                } label: {
                    Label("Details", systemImage: "info.circle")
                }

                if process.request?.sqlText != nil {
                    Button {
                        if let sql = process.request?.sqlText { onPopout(sql) }
                    } label: {
                        Label("View SQL", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                }

                Divider()

                Button(role: .destructive) {
                    pendingKillID = id
                    showKillAlert = true
                } label: {
                    Label("Kill Process", systemImage: "xmark.octagon")
                }
                .disabled(!canKill)
            }
        } primaryAction: { _ in
            onDoubleClick?()
        }
        .alert("Kill Process?", isPresented: $showKillAlert) {
            Button("Cancel", role: .cancel) { pendingKillID = nil }
            Button("Kill", role: .destructive) {
                guard let id = pendingKillID else { return }
                pendingKillID = nil
                onKill(id)
            }
        } message: {
            if let id = pendingKillID {
                Text("Are you sure you want to kill process \(id)? Any uncommitted work will be rolled back.")
            }
        }
    }
}
