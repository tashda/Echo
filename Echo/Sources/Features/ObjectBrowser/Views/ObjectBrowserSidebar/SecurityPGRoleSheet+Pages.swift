import SwiftUI
import PostgresKit

// MARK: - SecurityPGRoleSheet Page Views

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
                        .foregroundStyle(.tertiary)
                }
            }
        }

        Section("Account Expires") {
            TextField("Valid until", text: $validUntil, prompt: Text("YYYY-MM-DD HH:MM:SS or empty for no expiry"))
                .help("Account expiration timestamp. Leave empty for no expiry.")
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
                .foregroundStyle(.secondary)
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
                        .foregroundStyle(.secondary)
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

    // MARK: - Parameters Page

    @ViewBuilder
    var parametersPage: some View {
        Section("Role Parameters") {
            if roleParameters.isEmpty && !isEditing {
                Text("No role-level parameters configured.")
                    .foregroundStyle(.secondary)
                    .font(TypographyTokens.detail)
            }

            ForEach(Array(roleParameters.enumerated()), id: \.offset) { index, param in
                HStack {
                    Text(param.name)
                        .font(TypographyTokens.standard)
                        .frame(minWidth: 160, alignment: .leading)
                    Text(param.value)
                        .font(TypographyTokens.standard)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if isEditing {
                        Button(role: .destructive) {
                            roleParameters.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }

        if isEditing {
            Section("Add Parameter") {
                HStack(spacing: SpacingTokens.xs) {
                    Picker("Parameter", selection: $newParamName) {
                        Text("Select\u{2026}").tag("")
                        ForEach(availableParameters, id: \.self) { param in
                            Text(param).tag(param)
                        }
                    }
                    .frame(minWidth: 180)

                    TextField("Value", text: $newParamValue)

                    Button("Add") {
                        addParameter()
                    }
                    .disabled(newParamName.isEmpty || newParamValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    // MARK: - Security Labels Page

    @ViewBuilder
    var securityLabelsPage: some View {
        Section("Security Labels") {
            if securityLabels.isEmpty && !isEditing {
                Text("No security labels assigned to this role.")
                    .foregroundStyle(.secondary)
                    .font(TypographyTokens.detail)
            }

            ForEach(Array(securityLabels.enumerated()), id: \.offset) { index, label in
                HStack {
                    Text(label.provider)
                        .font(TypographyTokens.standard)
                        .frame(minWidth: 120, alignment: .leading)
                    Text(label.label)
                        .font(TypographyTokens.standard)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if isEditing {
                        Button(role: .destructive) {
                            securityLabels.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }

        if isEditing {
            Section("Add Security Label") {
                HStack(spacing: SpacingTokens.xs) {
                    TextField("Provider", text: $newLabelProvider)
                        .frame(minWidth: 120)

                    TextField("Label", text: $newLabelValue)

                    Button("Add") {
                        addSecurityLabel()
                    }
                    .disabled(newLabelProvider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newLabelValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    // MARK: - SQL Page

    @ViewBuilder
    var sqlPage: some View {
        Section("Generated SQL") {
            let sql = generateSQL()
            Text(sql)
                .font(TypographyTokens.monospaced)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SpacingTokens.xs)
        }
    }
}
