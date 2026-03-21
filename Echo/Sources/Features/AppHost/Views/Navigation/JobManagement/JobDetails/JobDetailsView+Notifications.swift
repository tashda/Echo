import SwiftUI

extension JobDetailsView {

    // MARK: - Notifications Tab

    /// Notification row model for the table display
    struct NotificationDisplayRow: Identifiable, Hashable {
        let id: String
        let type: String
        let target: String
        let level: String
    }

    var currentNotificationRows: [NotificationDisplayRow] {
        guard let props = viewModel.properties else { return [] }
        var rows: [NotificationDisplayRow] = []
        if props.notifyLevelEmail > 0, let op = props.notifyEmailOperator, !op.isEmpty {
            rows.append(NotificationDisplayRow(id: "email", type: "Email", target: op, level: notifyLevelName(props.notifyLevelEmail)))
        }
        if props.notifyLevelEventlog > 0 {
            rows.append(NotificationDisplayRow(id: "eventlog", type: "Event Log", target: "Windows Application Log", level: notifyLevelName(props.notifyLevelEventlog)))
        }
        return rows
    }

    var notificationsTab: some View {
        VStack(spacing: 0) {
            let rows = currentNotificationRows
            Table(of: NotificationDisplayRow.self) {
                TableColumn("Type") { (row: NotificationDisplayRow) in
                    Text(row.type)
                        .font(TypographyTokens.Table.category)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                TableColumn("Target") { (row: NotificationDisplayRow) in
                    Text(row.target)
                        .font(TypographyTokens.Table.name)
                }
                TableColumn("When") { (row: NotificationDisplayRow) in
                    Text(row.level)
                        .font(TypographyTokens.Table.status)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            } rows: {
                ForEach(rows) { row in
                    TableRow(row)
                }
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if rows.isEmpty {
                    Text("No notifications configured.")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            Divider()

            HStack {
                Spacer()
                Button {
                    syncNotificationFields()
                    showEditNotificationSheet = true
                } label: {
                    Label(currentNotificationRows.isEmpty ? "Configure Notifications" : "Edit Notifications", systemImage: currentNotificationRows.isEmpty ? "plus" : "pencil")
                }
                .controlSize(.small)
                .padding(SpacingTokens.xs)
            }
        }
        .onAppear { syncNotificationFields() }
        .onChange(of: viewModel.properties) { _, _ in syncNotificationFields() }
        .sheet(isPresented: $showEditNotificationSheet) {
            notificationEditorSheet
        }
    }

    func syncNotificationFields() {
        guard let props = viewModel.properties else { return }
        notifyLevel = props.notifyLevelEmail
        notifyOperator = props.notifyEmailOperator ?? ""
        notifyEventLogLevel = props.notifyLevelEventlog
        notificationsLoaded = true
    }

    private var notificationEditorSheet: some View {
        VStack(spacing: 0) {
            Form {
                Section("Email Notification") {
                    if viewModel.operators.isEmpty {
                        TextField("Operator", text: $notifyOperator, prompt: Text("e.g. DBA_Team"))
                    } else {
                        Picker("Operator", selection: $notifyOperator) {
                            Text("None").tag("")
                            ForEach(viewModel.operators) { op in
                                HStack {
                                    Text(op.name)
                                    if let email = op.emailAddress, !email.isEmpty {
                                        Text("(\(email))")
                                            .foregroundStyle(ColorTokens.Text.secondary)
                                    }
                                }
                                .tag(op.name)
                            }
                        }
                    }

                    Picker("Notify when", selection: $notifyLevel) {
                        Text("Never").tag(0)
                        Text("On success").tag(1)
                        Text("On failure").tag(2)
                        Text("On completion").tag(3)
                    }
                }

                Section("Windows Event Log") {
                    Picker("Write to event log", selection: $notifyEventLogLevel) {
                        Text("Never").tag(0)
                        Text("On success").tag(1)
                        Text("On failure").tag(2)
                        Text("On completion").tag(3)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") {
                    showEditNotificationSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    Task {
                        await viewModel.setNotification(
                            operatorName: notifyOperator.trimmingCharacters(in: .whitespacesAndNewlines),
                            level: notifyLevel,
                            eventLogLevel: notifyEventLogLevel
                        )
                        if viewModel.errorMessage == nil {
                            notificationEngine?.post(category: .jobNotificationSaved, message: "Notification saved")
                            showEditNotificationSheet = false
                            await viewModel.loadDetails()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(notifyLevel > 0 && notifyOperator.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(SpacingTokens.md2)
        }
        .frame(minWidth: 420, minHeight: 320)
    }

    func notifyLevelName(_ level: Int) -> String {
        switch level {
        case 1: return "On success"
        case 2: return "On failure"
        case 3: return "On completion"
        default: return "Never"
        }
    }
}
