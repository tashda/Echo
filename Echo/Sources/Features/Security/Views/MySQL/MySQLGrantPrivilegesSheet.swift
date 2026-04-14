import SwiftUI

struct MySQLGrantPrivilegesSheet: View {
    let databaseName: String
    let grantees: [MySQLPrivilegeGrantee]
    let onApply: (MySQLPrivilegeGrantee, [MySQLSchemaPrivilege], Bool) -> Void
    let onDismiss: () -> Void

    @State private var selectedGranteeID = ""
    @State private var selectedPrivileges: Set<MySQLSchemaPrivilege> = []
    @State private var withGrantOption = false

    var body: some View {
        SheetLayoutCustomFooter(title: "Grant Schema Privileges") {
            Form {
                Section("Scope") {
                    LabeledContent("Database") {
                        Text(databaseName)
                            .textSelection(.enabled)
                    }
                }

                Section("Grantee") {
                    PropertyRow(title: "Account") {
                        Picker("", selection: $selectedGranteeID) {
                            Text("Select an account").tag("")
                            ForEach(grantees) { grantee in
                                Text(grantee.accountName).tag(grantee.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }

                Section("Privileges") {
                    ForEach(MySQLSchemaPrivilege.allCases) { privilege in
                        Toggle(isOn: binding(for: privilege)) {
                            Text(privilege.rawValue)
                                .font(TypographyTokens.standard)
                        }
                        .toggleStyle(.checkbox)
                    }

                    PropertyRow(title: "WITH GRANT OPTION", subtitle: "Allow the grantee to grant the same privileges to others") {
                        Toggle("", isOn: $withGrantOption)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }

                Section("Preview") {
                    SQLPreviewSection(sql: generatedSQL)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        } footer: {
            Button("Cancel") { onDismiss() }
                .keyboardShortcut(.cancelAction)
            Spacer()
            Button("Grant") {
                guard let grantee = selectedGrantee else { return }
                onApply(grantee, selectedPrivileges.sorted { $0.rawValue < $1.rawValue }, withGrantOption)
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(selectedGrantee == nil || selectedPrivileges.isEmpty)
        }
        .frame(minWidth: 620, minHeight: 560)
    }

    private var selectedGrantee: MySQLPrivilegeGrantee? {
        grantees.first { $0.id == selectedGranteeID }
    }

    private var generatedSQL: String {
        guard let grantee = selectedGrantee else {
            return "-- Select an account to preview GRANT"
        }
        guard !selectedPrivileges.isEmpty else {
            return "-- Select one or more privileges"
        }

        let privileges = selectedPrivileges.map(\.rawValue).sorted().joined(separator: ", ")
        let grantOption = withGrantOption ? " WITH GRANT OPTION" : ""
        return """
        GRANT \(privileges) ON `\(databaseName)`.*
        TO \(grantee.accountName)\(grantOption);
        """
    }

    private func binding(for privilege: MySQLSchemaPrivilege) -> Binding<Bool> {
        Binding(
            get: { selectedPrivileges.contains(privilege) },
            set: { isSelected in
                if isSelected {
                    if privilege == .all {
                        selectedPrivileges = [.all]
                    } else {
                        selectedPrivileges.remove(.all)
                        selectedPrivileges.insert(privilege)
                    }
                } else {
                    selectedPrivileges.remove(privilege)
                }
            }
        )
    }
}
