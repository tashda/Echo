import MySQLKit
import SwiftUI

struct MySQLUserLimitsSheet: View {
    let accountName: String
    let initialLimits: MySQLAccountLimits
    let onApply: (MySQLAccountLimits) -> Void
    let onDismiss: () -> Void

    @State private var maxQueriesPerHour: String
    @State private var maxUpdatesPerHour: String
    @State private var maxConnectionsPerHour: String
    @State private var maxUserConnections: String

    init(
        accountName: String,
        initialLimits: MySQLAccountLimits,
        onApply: @escaping (MySQLAccountLimits) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.accountName = accountName
        self.initialLimits = initialLimits
        self.onApply = onApply
        self.onDismiss = onDismiss
        _maxQueriesPerHour = State(initialValue: "\(initialLimits.maxQueriesPerHour)")
        _maxUpdatesPerHour = State(initialValue: "\(initialLimits.maxUpdatesPerHour)")
        _maxConnectionsPerHour = State(initialValue: "\(initialLimits.maxConnectionsPerHour)")
        _maxUserConnections = State(initialValue: "\(initialLimits.maxUserConnections)")
    }

    var body: some View {
        SheetLayoutCustomFooter(title: "Edit Account Limits") {
            Form {
                Section("Account") {
                    PropertyRow(title: "User") {
                        Text(accountName)
                            .textSelection(.enabled)
                    }
                }

                Section("Limits") {
                    limitRow("Queries / Hour", value: $maxQueriesPerHour, prompt: "0")
                    limitRow("Updates / Hour", value: $maxUpdatesPerHour, prompt: "0")
                    limitRow("Connections / Hour", value: $maxConnectionsPerHour, prompt: "0")
                    limitRow("Max User Connections", value: $maxUserConnections, prompt: "0")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        } footer: {
            Button("Cancel") { onDismiss() }
                .keyboardShortcut(.cancelAction)
            Spacer()
            Button("Save") {
                onApply(
                    MySQLAccountLimits(
                        maxQueriesPerHour: Int(maxQueriesPerHour) ?? 0,
                        maxUpdatesPerHour: Int(maxUpdatesPerHour) ?? 0,
                        maxConnectionsPerHour: Int(maxConnectionsPerHour) ?? 0,
                        maxUserConnections: Int(maxUserConnections) ?? 0
                    )
                )
                onDismiss()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.defaultAction)
        }
        .frame(minWidth: 520, minHeight: 320)
    }

    private func limitRow(_ title: String, value: Binding<String>, prompt: String) -> some View {
        PropertyRow(title: title) {
            TextField("", text: value, prompt: Text(prompt))
                .textFieldStyle(.roundedBorder)
                .frame(width: 120)
                .multilineTextAlignment(.trailing)
        }
    }
}
