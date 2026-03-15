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
        VSplitView {
            let rows = currentNotificationRows
            Table(of: NotificationDisplayRow.self) {
                TableColumn("Type", value: \.type)
                TableColumn("Target", value: \.target)
                TableColumn("When", value: \.level)
            } rows: {
                ForEach(rows) { row in
                    TableRow(row)
                }
            }
            .frame(minHeight: 60)

            notificationEditForm
                .frame(minHeight: 100)
        }
        .onAppear { syncNotificationFields() }
        .onChange(of: viewModel.properties) { _, _ in syncNotificationFields() }
    }

    func syncNotificationFields() {
        guard !notificationsLoaded, let props = viewModel.properties else { return }
        notifyLevel = props.notifyLevelEmail
        notifyOperator = props.notifyEmailOperator ?? ""
        notifyEventLogLevel = props.notifyLevelEventlog
        notificationsLoaded = true
    }

    var notificationEditForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                Text("Email Notification")
                    .font(TypographyTokens.detail.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.secondary)

                if viewModel.operators.isEmpty {
                    TextField("Operator", text: $notifyOperator, prompt: Text("e.g. DBA Team"))
                        .textFieldStyle(.roundedBorder)
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

                Divider()

                Text("Windows Event Log")
                    .font(TypographyTokens.detail.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.secondary)

                Picker("Write to event log", selection: $notifyEventLogLevel) {
                    Text("Never").tag(0)
                    Text("On success").tag(1)
                    Text("On failure").tag(2)
                    Text("On completion").tag(3)
                }

                Divider()

                HStack {
                    Spacer()
                    Button("Save") {
                        Task {
                            await viewModel.setNotification(
                                operatorName: notifyOperator.trimmingCharacters(in: .whitespacesAndNewlines),
                                level: notifyLevel,
                                eventLogLevel: notifyEventLogLevel
                            )
                            if viewModel.errorMessage == nil {
                                notificationEngine?.post(category: .jobNotificationSaved, message: "Notification saved")
                                await viewModel.loadDetails()
                                if let props = viewModel.properties {
                                    notifyLevel = props.notifyLevelEmail
                                    notifyOperator = props.notifyEmailOperator ?? ""
                                    notifyEventLogLevel = props.notifyLevelEventlog
                                }
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(notifyLevel > 0 && notifyOperator.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(SpacingTokens.sm)
        }
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
