import SwiftUI
import PostgresWire

struct PostgresActivitySessions: View {
    let processes: [PostgresProcessInfo]
    @Binding var sortOrder: [KeyPathComparator<PostgresProcessInfo>]
    @Binding var selection: Set<PostgresProcessInfo.ID>
    let onPopout: (String) -> Void
    let onKill: (Int) -> Void
    var onDoubleClick: (() -> Void)?

    @State private var showKillAlert = false
    @State private var pendingKillPID: Int?

    private var sortedProcesses: [PostgresProcessInfo] {
        processes.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedProcesses, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("PID", value: \.pid) {
                Text("\($0.pid)").font(TypographyTokens.Table.numeric)
            }.width(min: 50, max: 70)

            TableColumn("User") {
                Text($0.userName ?? "")
                    .font(TypographyTokens.Table.name)
                    .foregroundStyle(($0.userName ?? "").isEmpty ? ColorTokens.Text.tertiary : ColorTokens.Text.primary)
            }.width(min: 80, ideal: 100)

            TableColumn("DB") {
                Text($0.databaseName ?? "")
                    .font(TypographyTokens.Table.name)
            }.width(min: 80, ideal: 100)

            TableColumn("State") {
                StatusBadge(text: $0.state ?? "", isSystem: ($0.userName ?? "").isEmpty)
            }.width(90)

            TableColumn("Duration") {
                DurationCell(queryStart: $0.queryStart, state: $0.state)
            }.width(min: 70, ideal: 90)

            TableColumn("App") {
                Text($0.applicationName ?? "\u{2014}")
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(($0.applicationName ?? "").isEmpty ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
                    .lineLimit(1)
            }.width(min: 80, ideal: 120)

            TableColumn("Client") {
                Text($0.clientAddress ?? "\u{2014}")
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(($0.clientAddress ?? "").isEmpty ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
            }.width(min: 80, ideal: 100)

            TableColumn("Query") {
                if let sql = $0.query, !sql.isEmpty {
                    SQLQueryCell(sql: sql, onPopout: onPopout)
                }
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: PostgresProcessInfo.ID.self) { selection in
            if let id = selection.first, let process = processes.first(where: { $0.id == id }) {
                Button {
                    if let sql = process.query { onPopout(sql) }
                } label: {
                    Label("Details", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .disabled(process.query == nil)

                Divider()

                Button(role: .destructive) {
                    pendingKillPID = Int(id)
                    showKillAlert = true
                } label: {
                    Label("Kill Process", systemImage: "xmark.octagon")
                }
            }
        } primaryAction: { _ in
            onDoubleClick?()
        }
        .alert("Kill Process?", isPresented: $showKillAlert) {
            Button("Cancel", role: .cancel) { pendingKillPID = nil }
            Button("Kill", role: .destructive) {
                guard let pid = pendingKillPID else { return }
                pendingKillPID = nil
                onKill(pid)
            }
        } message: {
            if let pid = pendingKillPID {
                Text("Are you sure you want to kill process \(pid)? Any uncommitted work will be rolled back.")
            }
        }
    }
}

private struct DurationCell: View {
    let queryStart: Date?
    let state: String?

    var body: some View {
        if let start = queryStart, state == "active" {
            let seconds = Date().timeIntervalSince(start)
            Text(formatDuration(seconds))
                .font(TypographyTokens.Table.numeric)
                .foregroundStyle(seconds > 60 ? ColorTokens.Status.warning : ColorTokens.Text.secondary)
        } else {
            Text("\u{2014}")
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 1 { return "<1s" }
        if seconds < 60 { return "\(Int(seconds))s" }
        if seconds < 3600 { return "\(Int(seconds / 60))m \(Int(seconds.truncatingRemainder(dividingBy: 60)))s" }
        return "\(Int(seconds / 3600))h \(Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60))m"
    }
}
