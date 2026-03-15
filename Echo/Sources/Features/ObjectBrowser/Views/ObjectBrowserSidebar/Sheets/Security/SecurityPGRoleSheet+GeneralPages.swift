import SwiftUI
import PostgresKit

// MARK: - SecurityPGRoleSheet General, Privileges, Membership Pages

extension SecurityPGRoleSheet {

    // MARK: - General Page

    @ViewBuilder
    var generalPage: some View {
        Section(isEditing ? "Role Properties" : "New Login/Group Role") {
            if isEditing {
                LabeledContent("Role Name", value: roleName)
            } else {
                TextField("Role Name", text: $roleName)
            }
        }

        Section("Authentication") {
            SecureField("Password", text: $password, prompt: Text(isEditing ? "Leave empty to keep current" : "Optional"))
            if !isEditing {
                SecureField("Confirm Password", text: $confirmPassword)
            }
        }

        Section("Connection") {
            Toggle("Can login", isOn: $canLogin)
            LabeledContent("Connection limit") {
                HStack(spacing: SpacingTokens.xs) {
                    TextField("", value: $connectionLimit, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    Text(connectionLimit == -1 ? "(unlimited)" : "")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
        }

        Section("Account Expires") {
            Toggle("Set expiration date", isOn: $hasExpiry)
                .onChange(of: hasExpiry) { _, enabled in
                    if enabled {
                        validUntil = Self.pgTimestampFormatter.string(from: validUntilDate)
                    } else {
                        validUntil = ""
                    }
                }

            if hasExpiry {
                DatePicker(
                    "Expires on",
                    selection: $validUntilDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.stepperField)
                .onChange(of: validUntilDate) { _, newDate in
                    validUntil = Self.pgTimestampFormatter.string(from: newDate)
                }
            }
        }

        Section("Comment") {
            TextField("Comment", text: $roleComment, prompt: Text("Optional description"), axis: .vertical)
                .lineLimit(3...6)
        }
    }

    // MARK: - Privileges Page

    @ViewBuilder
    var privilegesPage: some View {
        Section("Role Privileges") {
            Toggle("Superuser", isOn: $isSuperuser)
            Toggle("Create databases", isOn: $canCreateDB)
            Toggle("Create roles", isOn: $canCreateRole)
            Toggle("Inherit privileges", isOn: $inherit)
            Toggle("Replication", isOn: $isReplication)
            Toggle("Bypass row-level security", isOn: $bypassRLS)
        }

        Section {
            Text("Superuser grants all privileges and bypasses all permission checks. Bypass RLS allows the role to bypass all row-level security policies.")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
    }

    // MARK: - Membership Page

    @ViewBuilder
    var membershipPage: some View {
        if loadingRoles {
            Section {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Loading roles\u{2026}")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        } else {
            Section("Member Of") {
                membershipTable(
                    entries: $memberOfEntries,
                    availableRoles: availableRolesForMemberOf,
                    selectedNewRole: $selectedNewMemberOfRole,
                    onAdd: {
                        guard !selectedNewMemberOfRole.isEmpty else { return }
                        memberOfEntries.append(PGRoleMemberEntry(
                            name: selectedNewMemberOfRole,
                            adminOption: false,
                            inheritOption: true,
                            setOption: true
                        ))
                        selectedNewMemberOfRole = ""
                    },
                    onRemove: { indexSet in
                        memberOfEntries.remove(atOffsets: indexSet)
                    }
                )
            }

            if isEditing {
                Section("Members") {
                    membershipTable(
                        entries: $memberEntries,
                        availableRoles: availableRolesForMembers,
                        selectedNewRole: $selectedNewMemberRole,
                        onAdd: {
                            guard !selectedNewMemberRole.isEmpty else { return }
                            memberEntries.append(PGRoleMemberEntry(
                                name: selectedNewMemberRole,
                                adminOption: false,
                                inheritOption: true,
                                setOption: true
                            ))
                            selectedNewMemberRole = ""
                        },
                        onRemove: { indexSet in
                            memberEntries.remove(atOffsets: indexSet)
                        }
                    )
                }
            }
        }
    }
}
