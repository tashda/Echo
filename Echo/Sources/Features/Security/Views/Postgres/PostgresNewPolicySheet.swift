import SwiftUI
import PostgresKit

struct PostgresNewPolicySheet: View {
    let viewModel: PostgresDatabaseSecurityViewModel
    let onComplete: () -> Void

    @State private var policyName = ""
    @State private var tableName = ""
    @State private var command = "ALL"
    @State private var permissive = true
    @State private var roles = ""
    @State private var usingExpression = ""
    @State private var withCheckExpression = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let commands = ["ALL", "SELECT", "INSERT", "UPDATE", "DELETE"]

    private var isFormValid: Bool {
        !policyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !tableName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !isSubmitting
    }

    var body: some View {
        SheetLayout(
            title: "New Policy",
            icon: "lock.shield",
            subtitle: "Create a row-level security policy for a table.",
            primaryAction: "Create",
            canSubmit: isFormValid,
            isSubmitting: isSubmitting,
            errorMessage: errorMessage,
            onSubmit: { await submit() },
            onCancel: { onComplete() }
        ) {
            Form {
                Section("Policy") {
                    PropertyRow(title: "Policy Name") {
                        TextField("", text: $policyName, prompt: Text("e.g. tenant_isolation"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Table") {
                        TextField("", text: $tableName, prompt: Text("e.g. orders"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Command") {
                        Picker("", selection: $command) {
                            ForEach(commands, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    PropertyRow(title: "Type") {
                        Picker("", selection: $permissive) {
                            Text("Permissive").tag(true)
                            Text("Restrictive").tag(false)
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }

                Section("Access Control") {
                    PropertyRow(title: "Roles") {
                        TextField("", text: $roles, prompt: Text("e.g. app_user (blank = PUBLIC)"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "USING Expression") {
                        TextField("", text: $usingExpression, prompt: Text("e.g. tenant_id = current_setting('app.tenant')"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "WITH CHECK") {
                        TextField("", text: $withCheckExpression, prompt: Text("e.g. tenant_id = current_setting('app.tenant')"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 480, idealWidth: 540, minHeight: 400)
    }

    private func submit() async {
        let name = policyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let table = tableName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !table.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        await viewModel.createPolicy(
            name: name, table: table, schema: viewModel.policySchemaFilter,
            command: command, permissive: permissive,
            roles: roles, usingExpr: usingExpression, withCheckExpr: withCheckExpression
        )

        if viewModel.policies.contains(where: { $0.name == name }) {
            onComplete()
        } else {
            isSubmitting = false
            errorMessage = "Failed to create policy"
        }
    }
}
