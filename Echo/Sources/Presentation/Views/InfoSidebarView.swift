import SwiftUI

struct InfoSidebarView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Form {
            Section("Connection") {
                if let connection = appModel.selectedConnection {
                    LabeledContent("Name", value: connection.connectionName)
                    LabeledContent("Database", value: connection.database.isEmpty ? "Not selected" : connection.database)
                    LabeledContent("Host", value: connection.host)
                    LabeledContent("User", value: connection.username)
                } else {
                    Text("No connection selected")
                        .foregroundStyle(.secondary)
                }
            }

            if let session = appModel.sessionManager.activeSession {
                Section("Session") {
                    LabeledContent("Active Database", value: session.selectedDatabaseName ?? "None")
                    LabeledContent("Last Activity", value: session.lastActivity.formatted(date: .abbreviated, time: .shortened))
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .padding(.top, 52)
    }
}
