import MySQLKit
import SwiftUI

struct MySQLUserRoleMembershipSheet: View {
    let accountName: String
    let availableRoles: [MySQLRoleDefinition]
    let initialRoleIDs: Set<String>
    let onApply: (Set<String>) -> Void
    let onDismiss: () -> Void

    @State private var selectedRoleIDs: Set<String>

    init(
        accountName: String,
        availableRoles: [MySQLRoleDefinition],
        initialRoleIDs: Set<String>,
        onApply: @escaping (Set<String>) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.accountName = accountName
        self.availableRoles = availableRoles
        self.initialRoleIDs = initialRoleIDs
        self.onApply = onApply
        self.onDismiss = onDismiss
        _selectedRoleIDs = State(initialValue: initialRoleIDs)
    }

    var body: some View {
        SheetLayoutCustomFooter(title: "Role Membership") {
            Form {
                Section("Account") {
                    LabeledContent("User") {
                        Text(accountName)
                            .textSelection(.enabled)
                    }
                }

                Section("Roles") {
                    if availableRoles.isEmpty {
                        Text("No MySQL roles are available on this server.")
                            .font(TypographyTokens.formDescription)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    } else {
                        ForEach(availableRoles, id: \.id) { role in
                            Toggle(isOn: binding(for: role.id)) {
                                Text(role.accountName)
                                    .font(TypographyTokens.standard)
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        } footer: {
            Button("Cancel") { onDismiss() }
                .keyboardShortcut(.cancelAction)
            Spacer()
            Button("Save") {
                onApply(selectedRoleIDs)
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .frame(minWidth: 520, minHeight: 420)
    }

    private func binding(for roleID: String) -> Binding<Bool> {
        Binding(
            get: { selectedRoleIDs.contains(roleID) },
            set: { isSelected in
                if isSelected {
                    selectedRoleIDs.insert(roleID)
                } else {
                    selectedRoleIDs.remove(roleID)
                }
            }
        )
    }
}
