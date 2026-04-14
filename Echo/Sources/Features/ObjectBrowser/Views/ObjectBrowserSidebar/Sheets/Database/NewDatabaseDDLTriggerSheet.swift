import SwiftUI
import SQLServerKit

struct NewDatabaseDDLTriggerSheet: View {
    let databaseName: String
    let session: ConnectionSession
    let environmentState: EnvironmentState
    let onDismiss: () -> Void

    @State private var name = ""
    @State private var selectedEvents: Set<String> = []
    @State private var triggerBody = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    private static let eventCategories: [(title: String, events: [(value: String, label: String)])] = [
        ("Table", [
            ("CREATE_TABLE", "Create Table"),
            ("ALTER_TABLE", "Alter Table"),
            ("DROP_TABLE", "Drop Table"),
        ]),
        ("View", [
            ("CREATE_VIEW", "Create View"),
            ("ALTER_VIEW", "Alter View"),
            ("DROP_VIEW", "Drop View"),
        ]),
        ("Procedure", [
            ("CREATE_PROCEDURE", "Create Procedure"),
            ("ALTER_PROCEDURE", "Alter Procedure"),
            ("DROP_PROCEDURE", "Drop Procedure"),
        ]),
        ("Function", [
            ("CREATE_FUNCTION", "Create Function"),
            ("ALTER_FUNCTION", "Alter Function"),
            ("DROP_FUNCTION", "Drop Function"),
        ]),
        ("Trigger", [
            ("CREATE_TRIGGER", "Create Trigger"),
            ("ALTER_TRIGGER", "Alter Trigger"),
            ("DROP_TRIGGER", "Drop Trigger"),
        ]),
        ("Index", [
            ("CREATE_INDEX", "Create Index"),
            ("ALTER_INDEX", "Alter Index"),
            ("DROP_INDEX", "Drop Index"),
        ]),
        ("Schema", [
            ("CREATE_SCHEMA", "Create Schema"),
            ("ALTER_SCHEMA", "Alter Schema"),
            ("DROP_SCHEMA", "Drop Schema"),
        ]),
        ("User", [
            ("CREATE_USER", "Create User"),
            ("ALTER_USER", "Alter User"),
            ("DROP_USER", "Drop User"),
        ]),
        ("Role", [
            ("CREATE_ROLE", "Create Role"),
            ("ALTER_ROLE", "Alter Role"),
            ("DROP_ROLE", "Drop Role"),
        ]),
        ("Event Groups", [
            ("DDL_DATABASE_LEVEL_EVENTS", "DDL Database Level Events"),
            ("DDL_TABLE_EVENTS", "DDL Table Events"),
            ("DDL_VIEW_EVENTS", "DDL View Events"),
            ("DDL_PROCEDURE_EVENTS", "DDL Procedure Events"),
            ("DDL_FUNCTION_EVENTS", "DDL Function Events"),
            ("DDL_DATABASE_SECURITY_EVENTS", "DDL Database Security Events"),
        ]),
    ]

    private var canCreate: Bool {
        Self.isCreateValid(name: name, selectedEvents: selectedEvents, body: triggerBody, isCreating: isCreating)
    }

    var body: some View {
        SheetLayout(
            title: "New Database Trigger",
            icon: "bolt",
            subtitle: "Create a database-scoped DDL trigger that fires on schema changes.",
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

                    PropertyRow(title: "Database") {
                        Text(databaseName)
                            .foregroundStyle(ColorTokens.Text.secondary)
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
            "Create database trigger \(trimmedName)",
            connectionSessionID: session.id
        )

        do {
            guard let mssql = session.session as? MSSQLSession else { return }
            try await mssql.triggers.createDatabaseDDLTrigger(
                name: trimmedName,
                database: databaseName,
                events: Array(selectedEvents),
                body: triggerBody
            )
            handle.succeed()
            environmentState.notificationEngine?.post(
                category: .maintenanceCompleted,
                message: "Database trigger \(trimmedName) created in \(databaseName)."
            )
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
            handle.fail(error.localizedDescription)
            isCreating = false
        }
    }
}
