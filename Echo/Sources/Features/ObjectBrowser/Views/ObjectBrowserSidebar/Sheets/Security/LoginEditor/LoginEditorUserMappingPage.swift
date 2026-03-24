import SwiftUI

struct LoginEditorUserMappingPage: View {
    @Bindable var viewModel: LoginEditorViewModel
    let session: ConnectionSession

    var body: some View {
        mappingTableSection
    }

    // MARK: - Mapping Table

    @ViewBuilder
    private var mappingTableSection: some View {
        Section("Users mapped to this login") {
            Table(viewModel.mappingEntries, selection: $viewModel.selectedMappingDatabase) {
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
            .tableColumnAutoResize()
            .onChange(of: viewModel.selectedMappingDatabase) { _, newDB in
                if let db = newDB {
                    Task { await viewModel.loadDatabaseRoles(database: db, session: session) }
                }
            }
        }
    }

    // MARK: - Mapping Toggle Binding

    private func mappingToggleBinding(for database: String) -> Binding<Bool> {
        Binding(
            get: { viewModel.mappingEntries.first(where: { $0.databaseName == database })?.isMapped ?? false },
            set: { newValue in
                viewModel.toggleMapping(database: database, isMapped: newValue)
            }
        )
    }
}

// MARK: - Role Membership Inspector Content

struct LoginEditorUserMappingInspector: View {
    @Bindable var viewModel: LoginEditorViewModel
    let session: ConnectionSession

    var body: some View {
        if let selectedDB = viewModel.selectedMappingDatabase,
           let entry = viewModel.mappingEntries.first(where: { $0.databaseName == selectedDB }),
           entry.isMapped {
            Form {
                Section("Database roles for \(selectedDB)") {
                    if viewModel.isLoadingDBRoles {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("Loading roles\u{2026}")
                                .font(TypographyTokens.formDescription)
                                .foregroundStyle(ColorTokens.Text.secondary)
                        }
                    } else if viewModel.databaseRoleMemberships.isEmpty {
                        Text("No database roles available.")
                            .font(TypographyTokens.formDescription)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    } else {
                        ForEach(viewModel.databaseRoleMemberships) { role in
                            PropertyRow(title: role.roleName) {
                                Toggle("", isOn: roleToggleBinding(database: selectedDB, roleName: role.roleName))
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        } else if viewModel.selectedMappingDatabase != nil {
            ContentUnavailableView(
                "Not Mapped",
                systemImage: "person.crop.circle.badge.xmark",
                description: Text("Map this login to the selected database to manage role membership.")
            )
        } else {
            ContentUnavailableView(
                "Select a Database",
                systemImage: "externaldrive",
                description: Text("Select a database from the mapping table to view role membership.")
            )
        }
    }

    private func roleToggleBinding(database: String, roleName: String) -> Binding<Bool> {
        Binding(
            get: {
                viewModel.databaseRolesPerDB[database]?.first(where: { $0.roleName == roleName })?.isMember ?? false
            },
            set: { newValue in
                viewModel.toggleDatabaseRoleLocally(database: database, roleName: roleName, isMember: newValue)
            }
        )
    }
}
