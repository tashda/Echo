import MySQLKit
import SwiftUI

struct MySQLAdministrativeRolesSheet: View {
    let accountName: String
    let initialRoles: Set<MySQLAdministrativeRole>
    let onApply: (Set<MySQLAdministrativeRole>) -> Void
    let onDismiss: () -> Void

    @State private var selectedRoles: Set<MySQLAdministrativeRole>

    init(
        accountName: String,
        initialRoles: Set<MySQLAdministrativeRole>,
        onApply: @escaping (Set<MySQLAdministrativeRole>) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.accountName = accountName
        self.initialRoles = initialRoles
        self.onApply = onApply
        self.onDismiss = onDismiss
        _selectedRoles = State(initialValue: initialRoles)
    }

    var body: some View {
        SheetLayoutCustomFooter(title: "Administrative Roles") {
            Form {
                Section("Account") {
                    LabeledContent("User") {
                        Text(accountName)
                            .textSelection(.enabled)
                    }
                }

                Section("Roles") {
                    ForEach(MySQLAdministrativeRole.allCases, id: \.self) { role in
                        Toggle(isOn: binding(for: role)) {
                            Text(role.rawValue)
                                .font(TypographyTokens.standard)
                        }
                        .toggleStyle(.checkbox)
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
                onApply(selectedRoles)
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .frame(minWidth: 520, minHeight: 460)
    }

    private func binding(for role: MySQLAdministrativeRole) -> Binding<Bool> {
        Binding(
            get: { selectedRoles.contains(role) },
            set: { isSelected in
                if isSelected {
                    selectedRoles.insert(role)
                } else {
                    selectedRoles.remove(role)
                }
            }
        )
    }
}
