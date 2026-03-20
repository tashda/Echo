import SwiftUI
import SQLServerKit

// MARK: - SecurityLoginSheet Page Views

extension SecurityLoginSheet {

    // MARK: - General Page

    @ViewBuilder
    var generalPage: some View {
        Section(isEditing ? "Login Properties" : "New Login") {
            if isEditing {
                PropertyRow(title: "Login Name") {
                    Text(loginName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            } else {
                PropertyRow(title: "Login Name") {
                    TextField("", text: $loginName, prompt: Text("login_name"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }

            PropertyRow(title: "Authentication") {
                Picker("", selection: $authType) {
                    Text("SQL Server").tag(AuthType.sql)
                    Text("Windows").tag(AuthType.windows)
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }

        if authType == .sql {
            Section("Credentials") {
                PropertyRow(title: "Password") {
                    SecureField("", text: $password, prompt: Text(isEditing ? "Leave empty to keep current" : ""))
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
                
                PropertyRow(title: "Enforce policy") {
                    Toggle("", isOn: $enforcePasswordPolicy)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                
                PropertyRow(title: "Enforce expiration") {
                    Toggle("", isOn: $enforcePasswordExpiration)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(!enforcePasswordPolicy)
                }
            }
        }

        Section("Defaults") {
            PropertyRow(title: "Default Database") {
                Picker("", selection: $defaultDatabase) {
                    ForEach(availableDatabases, id: \.self) { db in
                        Text(db).tag(db)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            
            PropertyRow(title: "Default Language") {
                TextField("", text: $defaultLanguage, prompt: Text("Server default"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }

        Section("Status") {
            PropertyRow(title: "Login enabled") {
                Toggle("", isOn: $loginEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
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
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        } else {
            Section("Server Role Membership") {
                ForEach($availableServerRoles) { $role in
                    PropertyRow(title: role.name) {
                        HStack(spacing: SpacingTokens.xs) {
                            if role.isFixed {
                                Text("(fixed)")
                                    .font(TypographyTokens.formDescription)
                                    .foregroundStyle(ColorTokens.Text.tertiary)
                            }
                            Toggle("", isOn: $role.isMember)
                                .labelsHidden()
                                .toggleStyle(.switch)
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
                            .font(TypographyTokens.Table.name)
                    }
                    .width(min: 120, ideal: 160)

                    TableColumn("User") { entry in
                        Text(entry.userName ?? "\u{2014}")
                            .font(TypographyTokens.Table.secondaryName)
                            .foregroundStyle(entry.isMapped ? ColorTokens.Text.primary : ColorTokens.Text.tertiary)
                    }
                    .width(min: 100, ideal: 140)

                    TableColumn("Default Schema") { entry in
                        Text(entry.defaultSchema ?? "dbo")
                            .font(TypographyTokens.Table.secondaryName)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                    .width(min: 80, ideal: 100)
                }
                .tableStyle(.inset(alternatesRowBackgrounds: true))
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
                                .font(TypographyTokens.formDescription)
                                .foregroundStyle(ColorTokens.Text.secondary)
                        }
                    } else if databaseRoleMemberships.isEmpty {
                        Text("No fixed database roles available.")
                            .font(TypographyTokens.formDescription)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    } else {
                        ForEach($databaseRoleMemberships) { $role in
                            PropertyRow(title: role.roleName) {
                                Toggle("", isOn: $role.isMember)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                                    .onChange(of: role.isMember) { _, newValue in
                                        Task { await toggleDatabaseRole(database: selectedDB, role: role.roleName, isMember: newValue) }
                                    }
                            }
                        }
                    }
                }
            } else if selectedMappingDatabase != nil {
                Section("Database role membership") {
                    Text("Map the login to this database first to manage role membership.")
                        .font(TypographyTokens.formDescription)
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
