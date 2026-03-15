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

    // MARK: - Parameters Page

    @ViewBuilder
    var parametersPage: some View {
        if settingDefinitions.isEmpty {
            Section {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Loading parameter definitions\u{2026}")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        } else {
            Section("Role Parameters") {
                if roleParameters.isEmpty && !isEditing {
                    Text("No role-level parameters configured.")
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .font(TypographyTokens.detail)
                }

                ForEach(Array(roleParameters.enumerated()), id: \.offset) { index, param in
                    parameterRow(index: index, param: param)
                }
            }

            if isEditing {
                Section("Add Parameter") {
                    parameterAddControls
                }
            }

            Section {
                Text("\(settingDefinitions.count) configurable parameters available from this server.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
    }

    @ViewBuilder
    private func parameterRow(index: Int, param: PostgresDatabaseParameter) -> some View {
        let def = settingDefinition(for: param.name)
        HStack {
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                Text(param.name)
                    .font(TypographyTokens.standard)
                if let def, !def.shortDesc.isEmpty {
                    Text(def.shortDesc)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 200, alignment: .leading)

            Spacer()

            if isEditing, let def {
                parameterValueEditor(index: index, def: def)
            } else {
                Text(param.value)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.secondary)
                if let def, !def.unit.isEmpty {
                    Text(def.unit)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }

            if isEditing {
                Button(role: .destructive) {
                    roleParameters.remove(at: index)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(ColorTokens.Status.error)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func parameterValueEditor(index: Int, def: PostgresSettingDefinition) -> some View {
        switch def.vartype {
        case "bool":
            let isOn = Binding<Bool>(
                get: { roleParameters[safe: index]?.value == "on" },
                set: { roleParameters[safe: index] != nil ? roleParameters[index] = PostgresDatabaseParameter(name: def.name, value: $0 ? "on" : "off") : () }
            )
            Toggle("", isOn: isOn)
                .labelsHidden()

        case "enum":
            let selection = Binding<String>(
                get: { roleParameters[safe: index]?.value ?? "" },
                set: { roleParameters[safe: index] != nil ? roleParameters[index] = PostgresDatabaseParameter(name: def.name, value: $0) : () }
            )
            Picker("", selection: selection) {
                ForEach(def.enumVals, id: \.self) { val in
                    Text(val).tag(val)
                }
            }
            .labelsHidden()
            .frame(minWidth: 120)

        case "integer", "real":
            let text = Binding<String>(
                get: { roleParameters[safe: index]?.value ?? "" },
                set: { roleParameters[safe: index] != nil ? roleParameters[index] = PostgresDatabaseParameter(name: def.name, value: $0) : () }
            )
            HStack(spacing: SpacingTokens.xxs) {
                TextField("", text: text)
                    .frame(width: 100)
                    .multilineTextAlignment(.trailing)
                if !def.unit.isEmpty {
                    Text(def.unit)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }

        default: // string
            let text = Binding<String>(
                get: { roleParameters[safe: index]?.value ?? "" },
                set: { roleParameters[safe: index] != nil ? roleParameters[index] = PostgresDatabaseParameter(name: def.name, value: $0) : () }
            )
            TextField("", text: text)
                .frame(minWidth: 120)
        }
    }

    @ViewBuilder
    private var parameterAddControls: some View {
        let groupedParams = Dictionary(grouping: availableParameters, by: \.category)
        let sortedCategories = groupedParams.keys.sorted()

        Picker("Parameter", selection: $newParamName) {
            Text("Select parameter\u{2026}").tag("")
            ForEach(sortedCategories, id: \.self) { category in
                Section(category) {
                    ForEach(groupedParams[category] ?? [], id: \.name) { def in
                        Text(def.name).tag(def.name)
                    }
                }
            }
        }
        .frame(minWidth: 200)

        if !newParamName.isEmpty, let def = settingDefinition(for: newParamName) {
            HStack(spacing: SpacingTokens.xs) {
                switch def.vartype {
                case "bool":
                    Picker("Value", selection: $newParamValue) {
                        Text("on").tag("on")
                        Text("off").tag("off")
                    }
                    .frame(width: 100)
                    .onAppear { if newParamValue.isEmpty { newParamValue = def.bootVal == "on" ? "on" : "off" } }

                case "enum":
                    Picker("Value", selection: $newParamValue) {
                        Text("Select\u{2026}").tag("")
                        ForEach(def.enumVals, id: \.self) { val in
                            Text(val).tag(val)
                        }
                    }
                    .frame(minWidth: 120)

                case "integer", "real":
                    TextField("Value", text: $newParamValue)
                        .frame(width: 100)
                    if !def.unit.isEmpty {
                        Text(def.unit)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }

                default:
                    TextField("Value", text: $newParamValue)
                        .frame(minWidth: 120)
                }

                Button("Add") {
                    addParameter()
                }
                .disabled(newParamValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if !def.shortDesc.isEmpty {
                Text(def.shortDesc)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }

    // MARK: - Security Labels Page

    @ViewBuilder
    var securityLabelsPage: some View {
        Section("Security Labels") {
            if securityLabels.isEmpty && !isEditing {
                Text("No security labels assigned to this role.")
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .font(TypographyTokens.detail)
            }

            ForEach(Array(securityLabels.enumerated()), id: \.offset) { index, label in
                HStack {
                    Text(label.provider)
                        .font(TypographyTokens.standard)
                        .frame(minWidth: 120, alignment: .leading)
                    Text(label.label)
                        .font(TypographyTokens.standard)
                        .foregroundStyle(ColorTokens.Text.secondary)
                    Spacer()
                    if isEditing {
                        Button(role: .destructive) {
                            securityLabels.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(ColorTokens.Status.error)
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

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
