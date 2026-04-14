import SwiftUI
import PostgresKit

// MARK: - SecurityPGRoleSheet General, Privileges, Membership Pages

extension SecurityPGRoleSheet {

    // MARK: - General Page

    @ViewBuilder
    var generalPage: some View {
        Section(isEditing ? "Role Properties" : "New Login/Group Role") {
            if isEditing {
                PropertyRow(title: "Role Name") {
                    Text(roleName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            } else {
                PropertyRow(title: "Role Name") {
                    TextField("", text: $roleName)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }
        }

        Section("Authentication") {
            PropertyRow(title: "Password") {
                SecureField("", text: $password, prompt: Text(isEditing ? "Leave empty to keep current" : "Optional"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
            
            if !isEditing {
                PropertyRow(title: "Confirm Password") {
                    SecureField("", text: $confirmPassword)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }
        }

        Section("Connection") {
            PropertyRow(title: "Can login") {
                Toggle("", isOn: $canLogin)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            
            PropertyRow(
                title: "Connection limit",
                subtitle: connectionLimit == -1 ? "(unlimited)" : nil
            ) {
                TextField("", value: $connectionLimit, format: .number)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }

        Section("Account Expires") {
            PropertyRow(title: "Set expiration date") {
                Toggle("", isOn: $hasExpiry)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: hasExpiry) { _, enabled in
                        if enabled {
                            validUntil = Self.pgTimestampFormatter.string(from: validUntilDate)
                        } else {
                            validUntil = ""
                        }
                    }
            }

            if hasExpiry {
                PropertyRow(title: "Expires on") {
                    DatePicker(
                        "",
                        selection: $validUntilDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .datePickerStyle(.stepperField)
                    .onChange(of: validUntilDate) { _, newDate in
                        validUntil = Self.pgTimestampFormatter.string(from: newDate)
                    }
                }
            }
        }

        Section("Comment") {
            PropertyRow(title: "Comment") {
                TextField("", text: $roleComment, prompt: Text("Optional description"), axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(3...6)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    // MARK: - Privileges Page

    @ViewBuilder
    var privilegesPage: some View {
        Section("Role Privileges") {
            PropertyRow(title: "Superuser") {
                Toggle("", isOn: $isSuperuser)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            
            PropertyRow(title: "Create databases") {
                Toggle("", isOn: $canCreateDB)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            
            PropertyRow(title: "Create roles") {
                Toggle("", isOn: $canCreateRole)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            
            PropertyRow(title: "Inherit privileges") {
                Toggle("", isOn: $inherit)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            
            PropertyRow(title: "Replication") {
                Toggle("", isOn: $isReplication)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            
            PropertyRow(title: "Bypass RLS") {
                Toggle("", isOn: $bypassRLS)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }

        Section {
            Text("Superuser grants all privileges and bypasses all permission checks. Bypass RLS allows the role to bypass all row-level security policies.")
                .font(TypographyTokens.formDescription)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
    }

    // MARK: - Membership Page

    @ViewBuilder
    var membershipPage: some View {
        if loadingRoles {
            Section {
                HStack(spacing: SpacingTokens.xs) {
                    ProgressView().controlSize(.small)
                    Text("Loading roles\u{2026}")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        } else {
            Section("Member Of") {
                membershipTableContent(
                    entries: $memberOfEntries,
                    selection: $selectedMemberOfEntries,
                    availableRoles: availableRolesForMemberOf.filter { role in !memberOfEntries.contains { $0.name == role } },
                    onAdd: { role in
                        memberOfEntries.append(PGRoleMemberEntry(
                            name: role,
                            adminOption: false,
                            inheritOption: true,
                            setOption: true
                        ))
                    },
                    onRemove: { selected in
                        memberOfEntries.removeAll { selected.contains($0.name) }
                        selectedMemberOfEntries.removeAll()
                    }
                )
            }

            if isEditing {
                Section("Members") {
                    membershipTableContent(
                        entries: $memberEntries,
                        selection: $selectedMemberEntries,
                        availableRoles: availableRolesForMembers.filter { role in !memberEntries.contains { $0.name == role } },
                        onAdd: { role in
                            memberEntries.append(PGRoleMemberEntry(
                                name: role,
                                adminOption: false,
                                inheritOption: true,
                                setOption: true
                            ))
                        },
                        onRemove: { selected in
                            memberEntries.removeAll { selected.contains($0.name) }
                            selectedMemberEntries.removeAll()
                        }
                    )
                }
            }
        }
    }
}
