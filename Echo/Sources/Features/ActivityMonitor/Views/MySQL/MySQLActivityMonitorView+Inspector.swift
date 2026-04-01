import SwiftUI

extension MySQLActivityMonitorView {

    func pushProcessInspector(ids: Set<Int>) {
        guard let snap = mysqlSnapshot,
              let id = ids.first,
              let proc = snap.processes.first(where: { $0.id == id }) else {
            environmentState.dataInspectorContent = nil
            return
        }
        var fields: [DatabaseObjectInspectorContent.Field] = [
            .init(label: "Thread ID", value: "\(proc.id)"),
            .init(label: "User", value: proc.user),
            .init(label: "Host", value: proc.host),
            .init(label: "Database", value: proc.database ?? "\u{2014}"),
            .init(label: "Command", value: proc.command),
            .init(label: "State", value: proc.state ?? "Idle"),
            .init(label: "Duration", value: "\(proc.time) s"),
            .init(label: "Thread Type", value: proc.user == "system user" || proc.command.caseInsensitiveCompare("Daemon") == .orderedSame ? "Background" : "Foreground")
        ]
        if proc.time > 30 {
            fields.append(.init(label: "Warning", value: "Long-running query (\(proc.time)s)"))
        }
        let subtitle = proc.state ?? proc.command
        environmentState.dataInspectorContent = .databaseObject(DatabaseObjectInspectorContent(
            title: "Thread \(proc.id)",
            subtitle: subtitle,
            sqlText: proc.info,
            fields: fields
        ))
    }

    func pushInspectorContent(_ content: DatabaseObjectInspectorContent?) {
        environmentState.dataInspectorContent = content.map { .databaseObject($0) }
    }
}
