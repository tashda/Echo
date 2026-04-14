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

    private static let eventCategories: [(title: String, events: [(value: String, label: String)])] = [
        ("Database", [
            ("CREATE_DATABASE", "Create Database"),
            ("ALTER_DATABASE", "Alter Database"),
            ("DROP_DATABASE", "Drop Database"),
        ]),
        ("Login", [
            ("CREATE_LOGIN", "Create Login"),
            ("ALTER_LOGIN", "Alter Login"),
            ("DROP_LOGIN", "Drop Login"),
        ]),
        ("Server Role", [
            ("CREATE_SERVER_ROLE", "Create Server Role"),
            ("ALTER_SERVER_ROLE", "Alter Server Role"),
            ("DROP_SERVER_ROLE", "Drop Server Role"),
        ]),
        ("Endpoint", [
            ("CREATE_ENDPOINT", "Create Endpoint"),
            ("ALTER_ENDPOINT", "Alter Endpoint"),
            ("DROP_ENDPOINT", "Drop Endpoint"),
        ]),
        ("Credential", [
            ("CREATE_CREDENTIAL", "Create Credential"),
            ("ALTER_CREDENTIAL", "Alter Credential"),
            ("DROP_CREDENTIAL", "Drop Credential"),
        ]),
        ("Server Audit", [
            ("CREATE_SERVER_AUDIT", "Create Server Audit"),
            ("ALTER_SERVER_AUDIT", "Alter Server Audit"),
            ("DROP_SERVER_AUDIT", "Drop Server Audit"),
        ]),
        ("Event Groups", [
            ("DDL_SERVER_LEVEL_EVENTS", "DDL Server Level Events"),
            ("DDL_DATABASE_EVENTS", "DDL Database Events"),
            ("DDL_LOGIN_EVENTS", "DDL Login Events"),
            ("DDL_SERVER_SECURITY_EVENTS", "DDL Server Security Events"),
        ]),
    ]

    private var canCreate: Bool {
        Self.isCreateValid(name: name, selectedEvents: selectedEvents, body: triggerBody, isCreating: isCreating)
    }

    var body: some View {
        SheetLayout(
            title: "New Server Trigger",
            icon: "bolt",
            subtitle: "Create a server-scoped DDL trigger that fires on server-level events.",
            primaryAction: "Create",
            canSubmit: canCreate,
            isSubmitting: isCreating,
            errorMessage: errorMessage,
            onSubmit: { await createTrigger() },
            onCancel: { onDismiss() }
        ) {
            Form {
                Section {
                    PropertyRow(title: "Trigger Name") {
                        TextField("", text: $name, prompt: Text("e.g. trg_audit_ddl"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .fixedSize(horizontal: false, vertical: true)

            eventGrid
                .padding(.horizontal, SpacingTokens.lg)

            triggerBodyEditor
                .padding(.horizontal, SpacingTokens.lg)
                .padding(.top, SpacingTokens.md)
                .padding(.bottom, SpacingTokens.sm)
        }
        .frame(minWidth: 640, idealWidth: 700, minHeight: 560, idealHeight: 620)
    }

    // MARK: - Event Grid

    private var eventGrid: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("DDL Events")
                .font(TypographyTokens.formLabel.weight(.semibold))
                .padding(.leading, SpacingTokens.xxs)

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    alignment: .leading,
                    spacing: SpacingTokens.lg
                ) {
                    ForEach(Self.eventCategories, id: \.title) { category in
                        eventCategoryView(category.title, events: category.events)
                    }
                }
                .padding(SpacingTokens.sm)
            }
            .background(.quinary, in: .rect(cornerRadius: ShapeTokens.CornerRadius.medium))
        }
    }

    private func eventCategoryView(_ title: String, events: [(value: String, label: String)]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            Text(title)
                .font(TypographyTokens.detail.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.secondary)

            ForEach(events, id: \.value) { event in
                Toggle(event.label, isOn: eventBinding(for: event.value))
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

    // MARK: - Trigger Body

    private var triggerBodyEditor: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("Trigger Body")
                .font(TypographyTokens.formLabel.weight(.semibold))
                .padding(.leading, SpacingTokens.xxs)

            TextEditor(text: $triggerBody)
                .font(TypographyTokens.code)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding(SpacingTokens.xs)
                .background(.quinary, in: .rect(cornerRadius: ShapeTokens.CornerRadius.medium))
                .overlay(alignment: .topLeading) {
                    if triggerBody.isEmpty {
                        Text("BEGIN\n    -- trigger body\nEND")
                            .font(TypographyTokens.code)
                            .foregroundStyle(ColorTokens.Text.quaternary)
                            .padding(.top, SpacingTokens.sm)
                            .padding(.leading, SpacingTokens.sm)
                            .allowsHitTesting(false)
                    }
                }
        }
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
