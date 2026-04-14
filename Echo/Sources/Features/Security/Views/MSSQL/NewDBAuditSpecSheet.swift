import SwiftUI
import SQLServerKit

struct NewDBAuditSpecSheet: View {
    let session: ConnectionSession
    let database: String?
    let onComplete: () -> Void

    @State private var specName = ""
    @State private var availableAudits: [ServerAuditInfo] = []
    @State private var selectedAuditName: String?
    @State private var actions: [AuditAction] = []
    @State private var enableOnCreate = false
    @State private var isSubmitting = false
    @State private var isLoadingAudits = false
    @State private var errorMessage: String?

    // Builder state for adding actions
    @State private var newActionType: ActionType = .actionGroup
    @State private var newActionGroup: String = "DATABASE_OBJECT_ACCESS_GROUP"
    @State private var newAction: String = "SELECT"
    @State private var newSecurableClass: String = "SCHEMA"
    @State private var newSecurableName = "dbo"
    @State private var newPrincipal = "public"

    struct AuditAction: Identifiable {
        let id = UUID()
        let sqlExpression: String
    }

    enum ActionType: String, CaseIterable {
        case actionGroup = "Action Group"
        case action = "Action"
    }

    private static let actionGroups = [
        "APPLICATION_ROLE_CHANGE_PASSWORD_GROUP",
        "AUDIT_CHANGE_GROUP",
        "BACKUP_RESTORE_GROUP",
        "BATCH_COMPLETED_GROUP",
        "BATCH_STARTED_GROUP",
        "DATABASE_CHANGE_GROUP",
        "DATABASE_LOGOUT_GROUP",
        "DATABASE_OBJECT_ACCESS_GROUP",
        "DATABASE_OBJECT_CHANGE_GROUP",
        "DATABASE_OBJECT_OWNERSHIP_CHANGE_GROUP",
        "DATABASE_OBJECT_PERMISSION_CHANGE_GROUP",
        "DATABASE_OPERATION_GROUP",
        "DATABASE_OWNERSHIP_CHANGE_GROUP",
        "DATABASE_PERMISSION_CHANGE_GROUP",
        "DATABASE_PRINCIPAL_CHANGE_GROUP",
        "DATABASE_PRINCIPAL_IMPERSONATION_GROUP",
        "DATABASE_ROLE_MEMBER_CHANGE_GROUP",
        "DBCC_GROUP",
        "FAILED_DATABASE_AUTHENTICATION_GROUP",
        "SCHEMA_OBJECT_ACCESS_GROUP",
        "SCHEMA_OBJECT_CHANGE_GROUP",
        "SCHEMA_OBJECT_OWNERSHIP_CHANGE_GROUP",
        "SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP",
        "SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP",
        "TRANSACTION_GROUP",
        "USER_CHANGE_PASSWORD_GROUP",
        "USER_DEFINED_AUDIT_GROUP"
    ]

    private static let dmlActions = ["SELECT", "INSERT", "UPDATE", "DELETE", "EXECUTE", "RECEIVE", "REFERENCES"]
    private static let securableClasses = ["SCHEMA", "OBJECT", "DATABASE"]

    private var isFormValid: Bool {
        let name = specName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && selectedAuditName != nil && !actions.isEmpty && !isSubmitting
    }

    var body: some View {
        SheetLayout(
            title: "New Database Audit Specification",
            icon: "checklist",
            subtitle: "Create a database audit specification.",
            primaryAction: "Create",
            canSubmit: isFormValid,
            isSubmitting: isSubmitting,
            errorMessage: errorMessage,
            onSubmit: { await submit() },
            onCancel: { onComplete() }
        ) {
            Form {
                Section("General") {
                    PropertyRow(title: "Specification Name") {
                        TextField("", text: $specName, prompt: Text("e.g. DBAudit_DML"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }

                    PropertyRow(title: "Server Audit") {
                        Picker("", selection: $selectedAuditName) {
                            Text("Select an audit").tag(nil as String?)
                            ForEach(availableAudits) { audit in
                                Text(audit.name).tag(audit.name as String?)
                            }
                        }
                        .labelsHidden()
                    }

                    PropertyRow(title: "Enable on Create") {
                        Toggle("", isOn: $enableOnCreate)
                            .labelsHidden()
                    }
                }

                Section("Add Action") {
                    PropertyRow(title: "Type") {
                        Picker("", selection: $newActionType) {
                            ForEach(ActionType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .labelsHidden()
                    }

                    if newActionType == .actionGroup {
                        PropertyRow(title: "Action Group") {
                            Picker("", selection: $newActionGroup) {
                                ForEach(Self.actionGroups, id: \.self) { group in
                                    Text(group).tag(group)
                                }
                            }
                            .labelsHidden()
                        }
                    } else {
                        PropertyRow(title: "Action") {
                            Picker("", selection: $newAction) {
                                ForEach(Self.dmlActions, id: \.self) { action in
                                    Text(action).tag(action)
                                }
                            }
                            .labelsHidden()
                        }

                        PropertyRow(title: "On") {
                            HStack(spacing: SpacingTokens.xs) {
                                Picker("", selection: $newSecurableClass) {
                                    ForEach(Self.securableClasses, id: \.self) { cls in
                                        Text(cls).tag(cls)
                                    }
                                }
                                .labelsHidden()
                                .frame(maxWidth: 100)

                                Text("::")
                                    .foregroundStyle(ColorTokens.Text.tertiary)

                                TextField("", text: $newSecurableName, prompt: Text("dbo"))
                                    .textFieldStyle(.plain)
                            }
                        }

                        PropertyRow(title: "By") {
                            TextField("", text: $newPrincipal, prompt: Text("public"))
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    HStack {
                        Spacer()
                        Button("Add") { addAction() }
                            .buttonStyle(.bordered)
                    }
                }

                if !actions.isEmpty {
                    Section("Audit Actions (\(actions.count))") {
                        ForEach(actions) { action in
                            HStack {
                                Text(action.sqlExpression)
                                    .font(TypographyTokens.code)
                                    .foregroundStyle(ColorTokens.Text.secondary)
                                    .lineLimit(1)
                                Spacer()
                                Button {
                                    actions.removeAll { $0.id == action.id }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(ColorTokens.Status.error)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 500, idealWidth: 540, minHeight: 460)
        .task { await loadAudits() }
    }

    private func addAction() {
        let expr: String
        if newActionType == .actionGroup {
            expr = newActionGroup
        } else {
            let securable = newSecurableName.trimmingCharacters(in: .whitespacesAndNewlines)
            let principal = newPrincipal.trimmingCharacters(in: .whitespacesAndNewlines)
            expr = "\(newAction) ON \(newSecurableClass)::\(securable.isEmpty ? "dbo" : securable) BY \(principal.isEmpty ? "public" : principal)"
        }
        actions.append(AuditAction(sqlExpression: expr))
    }

    private func loadAudits() async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isLoadingAudits = true
        defer { isLoadingAudits = false }
        do {
            availableAudits = try await mssql.audit.listServerAudits()
        } catch {
            availableAudits = []
        }
    }

    private func submit() async {
        guard let mssql = session.session as? MSSQLSession,
              let auditName = selectedAuditName else { return }

        let name = specName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !actions.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        do {
            if let db = database {
                _ = try? await session.session.sessionForDatabase(db)
            }
            let actionStrings = actions.map { $0.sqlExpression }
            try await mssql.audit.createDatabaseAuditSpecification(name: name, auditName: auditName, actions: actionStrings)
            if enableOnCreate {
                try await mssql.audit.setDatabaseAuditSpecificationState(name: name, enabled: true)
            }
            onComplete()
        } catch {
            isSubmitting = false
            errorMessage = error.localizedDescription
        }
    }
}
