import SwiftUI
import SQLServerKit

struct NewServerTriggerSheet: View {
    let session: ConnectionSession
    let environmentState: EnvironmentState
    let onDismiss: () -> Void

    @State private var name = ""
    @State private var selectedEvents: Set<String> = []
    @State private var triggerBody = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    private var canCreate: Bool {
        Self.isCreateValid(name: name, selectedEvents: selectedEvents, body: triggerBody, isCreating: isCreating)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Trigger Name") {
                    TextField("", text: $name, prompt: Text("e.g. trg_audit_ddl"))
                }

                Section("DDL Events") {
                    eventSelectionView
                }

                Section("Trigger Body") {
                    TextEditor(text: $triggerBody)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 120)
                        .overlay(alignment: .topLeading) {
                            if triggerBody.isEmpty {
                                Text("BEGIN\n    -- trigger body\nEND")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(ColorTokens.Text.quaternary)
                                    .padding(.top, SpacingTokens.xxs)
                                    .padding(.leading, SpacingTokens.xxs2)
                                    .allowsHitTesting(false)
                            }
                        }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            footerView
        }
        .frame(minWidth: 560, minHeight: 480)
        .frame(idealWidth: 600, idealHeight: 540)
    }

    // MARK: - Subviews

    private var eventSelectionView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                eventCategory("Database", events: ["CREATE_DATABASE", "ALTER_DATABASE", "DROP_DATABASE"])
                eventCategory("Login", events: ["CREATE_LOGIN", "ALTER_LOGIN", "DROP_LOGIN"])
                eventCategory("Server Role", events: ["CREATE_SERVER_ROLE", "ALTER_SERVER_ROLE", "DROP_SERVER_ROLE"])
                eventCategory("Endpoint", events: ["CREATE_ENDPOINT", "ALTER_ENDPOINT", "DROP_ENDPOINT"])
                eventCategory("Credential", events: ["CREATE_CREDENTIAL", "ALTER_CREDENTIAL", "DROP_CREDENTIAL"])
                eventCategory("Server Audit", events: ["CREATE_SERVER_AUDIT", "ALTER_SERVER_AUDIT", "DROP_SERVER_AUDIT"])
                eventCategory("Event Groups", events: [
                    "DDL_SERVER_LEVEL_EVENTS",
                    "DDL_DATABASE_EVENTS",
                    "DDL_LOGIN_EVENTS",
                    "DDL_SERVER_SECURITY_EVENTS"
                ])
            }
            .padding(.vertical, SpacingTokens.xxs)
        }
        .frame(maxHeight: 200)
    }

    private func eventCategory(_ title: String, events: [String]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            Text(title)
                .font(TypographyTokens.detail.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.secondary)

            ForEach(events, id: \.self) { event in
                Toggle(event, isOn: eventBinding(for: event))
                    .toggleStyle(.checkbox)
                    .font(TypographyTokens.detail)
            }
        }
    }

    private func eventBinding(for event: String) -> Binding<Bool> {
        Binding(
            get: { selectedEvents.contains(event) },
            set: { isOn in
                if isOn { selectedEvents.insert(event) } else { selectedEvents.remove(event) }
            }
        )
    }

    private var footerView: some View {
        HStack {
            if let error = errorMessage {
                Text(error)
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Status.error)
                    .lineLimit(2)
            }
            Spacer()
            if isCreating {
                ProgressView()
                    .controlSize(.small)
            }
            Button("Cancel") { onDismiss() }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
            Button("Create") {
                Task { await createTrigger() }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!canCreate)
        }
        .padding(SpacingTokens.md)
    }

    // MARK: - Validation (Internal for testability)

    static func isCreateValid(name: String, selectedEvents: Set<String>, body: String, isCreating: Bool) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !selectedEvents.isEmpty
            && !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isCreating
    }

    // MARK: - Actions

    private func createTrigger() async {
        isCreating = true
        errorMessage = nil
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let handle = AppDirector.shared.activityEngine.begin(
            "Create server trigger \(trimmedName)",
            connectionSessionID: session.id
        )

        do {
            guard let mssql = session.session as? MSSQLSession else { return }
            try await mssql.triggers.createServerTrigger(
                name: trimmedName,
                events: Array(selectedEvents),
                body: triggerBody
            )
            handle.succeed()
            environmentState.notificationEngine?.post(
                category: .maintenanceCompleted,
                message: "Server trigger \(trimmedName) created."
            )
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
            handle.fail(error.localizedDescription)
            isCreating = false
        }
    }
}
