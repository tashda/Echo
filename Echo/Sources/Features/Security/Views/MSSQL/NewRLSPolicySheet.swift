import SwiftUI
import SQLServerKit

struct NewRLSPolicySheet: View {
    let viewModel: DatabaseSecurityViewModel
    let onComplete: () -> Void

    @State private var policyName = ""
    @State private var policySchema = "dbo"
    @State private var filterFunction = ""
    @State private var filterFunctionSchema = "dbo"
    @State private var targetTable = ""
    @State private var targetSchema = "dbo"
    @State private var predicateType: PredicateType = .filter
    @State private var enabled = true
    @State private var schemaBound = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        !policyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !filterFunction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !targetTable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !isSubmitting
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Security Policy") {
                    PropertyRow(title: "Policy Name") {
                        TextField("", text: $policyName, prompt: Text("e.g. FilterPolicy"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Policy Schema") {
                        TextField("", text: $policySchema, prompt: Text("e.g. dbo"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Enabled") {
                        Toggle("", isOn: $enabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                    PropertyRow(title: "Schema Bound") {
                        Toggle("", isOn: $schemaBound)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }

                Section("Predicate") {
                    PropertyRow(title: "Type") {
                        Picker("", selection: $predicateType) {
                            Text("Filter").tag(PredicateType.filter)
                            Text("Block").tag(PredicateType.block)
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    PropertyRow(title: "Function Name") {
                        TextField("", text: $filterFunction, prompt: Text("e.g. fn_securitypredicate"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Function Schema") {
                        TextField("", text: $filterFunctionSchema, prompt: Text("e.g. dbo"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Target") {
                    PropertyRow(title: "Table Name") {
                        TextField("", text: $targetTable, prompt: Text("e.g. Employees"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Table Schema") {
                        TextField("", text: $targetSchema, prompt: Text("e.g. dbo"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            HStack(spacing: SpacingTokens.sm) {
                if let error = errorMessage {
                    Text(error)
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Status.error)
                        .lineLimit(1)
                }

                Spacer()

                Button("Cancel") { onComplete() }
                    .keyboardShortcut(.cancelAction)

                Button("Create") { Task { await submit() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isFormValid)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, SpacingTokens.md2)
            .padding(.vertical, SpacingTokens.sm2)
            .background(.bar)
        }
        .frame(minWidth: 440, idealWidth: 480, minHeight: 440)
        .navigationTitle("New Security Policy")
    }

    private func submit() async {
        guard let mssql = viewModel.session as? MSSQLSession else {
            errorMessage = "Not connected to SQL Server"
            return
        }

        isSubmitting = true
        errorMessage = nil

        do {
            _ = try? await viewModel.session.sessionForDatabase(viewModel.selectedDatabase ?? "")
            try await mssql.security.createSecurityPolicy(
                name: policyName.trimmingCharacters(in: .whitespacesAndNewlines),
                schema: policySchema.trimmingCharacters(in: .whitespacesAndNewlines),
                filterFunction: filterFunction.trimmingCharacters(in: .whitespacesAndNewlines),
                filterFunctionSchema: filterFunctionSchema.trimmingCharacters(in: .whitespacesAndNewlines),
                targetTable: targetTable.trimmingCharacters(in: .whitespacesAndNewlines),
                targetSchema: targetSchema.trimmingCharacters(in: .whitespacesAndNewlines),
                predicateType: predicateType,
                enabled: enabled,
                schemaBound: schemaBound
            )
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
        }
    }
}
