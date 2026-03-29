import SwiftUI
import SQLServerKit

struct NewRLSPolicySheet: View {
    let viewModel: DatabaseSecurityViewModel
    let onComplete: () -> Void

    @State private var policyName = ""
    @State private var policySchema = "dbo"
    @State private var enabled = true
    @State private var schemaBound = true
    @State private var predicates: [PredicateEntry] = [PredicateEntry()]
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        !policyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !predicates.isEmpty
        && predicates.allSatisfy(\.isValid)
        && !isSubmitting
    }

    var body: some View {
        SheetLayout(
            title: "New Security Policy",
            icon: "lock.shield",
            subtitle: "Create a row-level security policy with one or more predicates.",
            primaryAction: "Create",
            canSubmit: isFormValid,
            isSubmitting: isSubmitting,
            errorMessage: errorMessage,
            onSubmit: { await submit() },
            onCancel: { onComplete() }
        ) {
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

                predicatesSections
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 480, idealWidth: 520, minHeight: 500)
    }

    // MARK: - Predicates

    @ViewBuilder
    private var predicatesSections: some View {
        ForEach($predicates) { $entry in
            Section {
                PropertyRow(title: "Type") {
                    Picker("", selection: $entry.predicateType) {
                        Text("Filter").tag(PredicateType.filter)
                        Text("Block").tag(PredicateType.block)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                if entry.predicateType == .block {
                    PropertyRow(title: "Block Operation") {
                        Picker("", selection: $entry.blockOperation) {
                            Text("After Insert").tag(SQLServerKit.BlockOperation.afterInsert)
                            Text("After Update").tag(SQLServerKit.BlockOperation.afterUpdate)
                            Text("Before Update").tag(SQLServerKit.BlockOperation.beforeUpdate)
                            Text("Before Delete").tag(SQLServerKit.BlockOperation.beforeDelete)
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }

                PropertyRow(title: "Function Name") {
                    TextField("", text: $entry.functionName, prompt: Text("e.g. fn_securitypredicate"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
                PropertyRow(title: "Function Schema") {
                    TextField("", text: $entry.functionSchema, prompt: Text("e.g. dbo"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
                PropertyRow(title: "Target Table") {
                    TextField("", text: $entry.targetTable, prompt: Text("e.g. Employees"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
                PropertyRow(title: "Target Schema") {
                    TextField("", text: $entry.targetSchema, prompt: Text("e.g. dbo"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                HStack {
                    Text("Predicate \(predicateIndex(for: entry) + 1)")
                    Spacer()
                    if predicates.count > 1 {
                        Button(role: .destructive) {
                            predicates.removeAll { $0.id == entry.id }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(ColorTokens.Status.error)
                    }
                }
            }
        }

        Section {
            Button {
                predicates.append(PredicateEntry())
            } label: {
                Label("Add Predicate", systemImage: "plus.circle")
            }
            .buttonStyle(.borderless)
        }
    }

    private func predicateIndex(for entry: PredicateEntry) -> Int {
        predicates.firstIndex { $0.id == entry.id } ?? 0
    }

    // MARK: - Submit

    private func submit() async {
        guard let mssql = viewModel.session as? MSSQLSession else {
            errorMessage = "Not connected to SQL Server"
            return
        }

        isSubmitting = true
        errorMessage = nil

        do {
            _ = try? await viewModel.session.sessionForDatabase(viewModel.selectedDatabase ?? "")

            let definitions = predicates.map { entry in
                SecurityPredicateDefinition(
                    predicateType: entry.predicateType,
                    functionName: entry.functionName.trimmingCharacters(in: .whitespacesAndNewlines),
                    functionSchema: entry.functionSchema.trimmingCharacters(in: .whitespacesAndNewlines),
                    targetTable: entry.targetTable.trimmingCharacters(in: .whitespacesAndNewlines),
                    targetSchema: entry.targetSchema.trimmingCharacters(in: .whitespacesAndNewlines),
                    blockOperation: entry.predicateType == .block ? entry.blockOperation : nil
                )
            }

            try await mssql.security.createSecurityPolicy(
                name: policyName.trimmingCharacters(in: .whitespacesAndNewlines),
                schema: policySchema.trimmingCharacters(in: .whitespacesAndNewlines),
                predicates: definitions,
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

// MARK: - Predicate Entry

extension NewRLSPolicySheet {

    struct PredicateEntry: Identifiable {
        let id = UUID()
        var predicateType: PredicateType = .filter
        var blockOperation: SQLServerKit.BlockOperation = .afterInsert
        var functionName = ""
        var functionSchema = "dbo"
        var targetTable = ""
        var targetSchema = "dbo"

        var isValid: Bool {
            !functionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !targetTable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
