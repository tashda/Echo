import SwiftUI
import SQLServerKit

// MARK: - SecurityLoginSheet Page Views

extension SecurityLoginSheet {

    // MARK: - General Page

    @ViewBuilder
    var generalPage: some View {
        Section(isEditing ? "Login Properties" : "New Login") {
            if isEditing {
                LabeledContent("Login Name", value: loginName)
            } else {
                TextField("Login Name", text: $loginName)
            }

            Picker("Authentication", selection: $authType) {
                Text("SQL Server Authentication").tag(AuthType.sql)
                Text("Windows Authentication").tag(AuthType.windows)
            }
        }

        if authType == .sql {
            Section("Credentials") {
                SecureField("Password", text: $password, prompt: Text(isEditing ? "Leave empty to keep current" : ""))
                if !isEditing {
                    SecureField("Confirm Password", text: $confirmPassword)
                }
                Toggle("Enforce password policy", isOn: $enforcePasswordPolicy)
                Toggle("Enforce password expiration", isOn: $enforcePasswordExpiration)
                    .disabled(!enforcePasswordPolicy)
            }
        }

        Section("Defaults") {
            Picker("Default Database", selection: $defaultDatabase) {
                ForEach(availableDatabases, id: \.self) { db in
                    Text(db).tag(db)
                }
            }
            TextField("Default Language", text: $defaultLanguage, prompt: Text("Server default"))
                .help("Leave empty to use the server default language.")
        }

        Section("Status") {
            Toggle("Login enabled", isOn: $loginEnabled)
        }
    }

    // MARK: - Server Roles Page

    @ViewBuilder
    var serverRolesPage: some View {
        if loadingRoles {
            Section {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Loading server roles\u{2026}")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        } else {
            Section("Server Role Membership") {
                ForEach($availableServerRoles) { $role in
                    Toggle(isOn: $role.isMember) {
                        HStack {
                            Text(role.name)
                            if role.isFixed {
                                Text("(fixed)")
                                    .font(TypographyTokens.label)
                                    .foregroundStyle(ColorTokens.Text.tertiary)
                            }
                        }
                    }
                    .disabled(role.name == "public")
                }
            }
        }
    }

    // MARK: - Database Mapping Page

    @ViewBuilder
    var databaseMappingPage: some View {
        if loadingMappings {
            Section {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Loading database mappings\u{2026}")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        } else {
            Section("Users mapped to this login") {
                Table(databaseMappingEntries, selection: $selectedMappingDatabase) {
                    TableColumn("Map") { entry in
                        Toggle("", isOn: mappingToggleBinding(for: entry.databaseName))
                            .labelsHidden()
                    }
                    .width(40)

                    TableColumn("Database") { entry in
                        Text(entry.databaseName)
                            .font(TypographyTokens.standard)
                    }
                    .width(min: 120, ideal: 160)

                    TableColumn("User") { entry in
                        Text(entry.userName ?? "")
                            .font(TypographyTokens.standard)
                            .foregroundStyle(entry.isMapped ? ColorTokens.Text.primary : ColorTokens.Text.tertiary)
                    }
                    .width(min: 100, ideal: 140)

                    TableColumn("Default Schema") { entry in
                        Text(entry.defaultSchema ?? "dbo")
                            .font(TypographyTokens.standard)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                    .width(min: 80, ideal: 100)
                }
                .tableStyle(.bordered)
                .scrollContentBackground(.visible)
                .frame(height: min(max(CGFloat(databaseMappingEntries.count) * 28 + 32, 120), 240))
                .onChange(of: selectedMappingDatabase) { _, newDB in
                    if let db = newDB {
                        Task { await loadDatabaseRoles(for: db) }
                    }
                }
            }

            if let selectedDB = selectedMappingDatabase,
               let entry = databaseMappingEntries.first(where: { $0.databaseName == selectedDB }),
               entry.isMapped {
                Section("Database role membership for: \(selectedDB)") {
                    if loadingDatabaseRoles {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("Loading roles\u{2026}")
                                .font(TypographyTokens.detail)
                                .foregroundStyle(ColorTokens.Text.secondary)
                        }
                    } else if databaseRoleMemberships.isEmpty {
                        Text("No fixed database roles available.")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    } else {
                        ForEach($databaseRoleMemberships) { $role in
                            Toggle(role.roleName, isOn: $role.isMember)
                                .onChange(of: role.isMember) { _, newValue in
                                    Task { await toggleDatabaseRole(database: selectedDB, role: role.roleName, isMember: newValue) }
                                }
                        }
                    }
                }
            } else if selectedMappingDatabase != nil {
                Section("Database role membership") {
                    Text("Map the login to this database first to manage role membership.")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }
    }

    func mappingToggleBinding(for database: String) -> Binding<Bool> {
        Binding(
            get: { databaseMappingEntries.first(where: { $0.databaseName == database })?.isMapped ?? false },
            set: { newValue in
                Task {
                    if newValue {
                        await mapToDatabase(database: database)
                    } else {
                        await unmapFromDatabase(database: database)
                    }
                }
            }
        )
    }
}
