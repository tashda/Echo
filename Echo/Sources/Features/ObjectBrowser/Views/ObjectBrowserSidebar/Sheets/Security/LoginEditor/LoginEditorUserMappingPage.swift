import SwiftUI

struct LoginEditorUserMappingPage: View {
    @Bindable var viewModel: LoginEditorViewModel
    let session: ConnectionSession

    var body: some View {
        if viewModel.isLoadingMappings {
            Section {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Loading database mappings\u{2026}")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        } else {
            mappingTableSection
            roleMembershipSection
        }
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

    // MARK: - Role Membership

    @ViewBuilder
    private var roleMembershipSection: some View {
        if let selectedDB = viewModel.selectedMappingDatabase,
           let entry = viewModel.mappingEntries.first(where: { $0.databaseName == selectedDB }),
           entry.isMapped {
            Section("Database role membership for: \(selectedDB)") {
                if viewModel.isLoadingDBRoles {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Loading roles\u{2026}")
                            .font(TypographyTokens.formDescription)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                } else if viewModel.databaseRoleMemberships.isEmpty {
                    Text("No fixed database roles available.")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                } else {
                    ForEach($viewModel.databaseRoleMemberships) { $role in
                        PropertyRow(title: role.roleName) {
                            Toggle("", isOn: $role.isMember)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .onChange(of: role.isMember) { _, newValue in
                                    Task {
                                        await viewModel.toggleDatabaseRole(
                                            database: selectedDB,
                                            role: role.roleName,
                                            isMember: newValue,
                                            session: session
                                        )
                                    }
                                }
                        }
                    }
                }
            }
        } else if viewModel.selectedMappingDatabase != nil {
            Section("Database role membership") {
                Text("Map the login to this database first to manage role membership.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }

    // MARK: - Mapping Toggle Binding

    private func mappingToggleBinding(for database: String) -> Binding<Bool> {
        Binding(
            get: { viewModel.mappingEntries.first(where: { $0.databaseName == database })?.isMapped ?? false },
            set: { newValue in
                Task {
                    if newValue {
                        await viewModel.mapToDatabase(database: database, session: session)
                    } else {
                        await viewModel.unmapFromDatabase(database: database, session: session)
                    }
                }
            }
        )
    }
}
