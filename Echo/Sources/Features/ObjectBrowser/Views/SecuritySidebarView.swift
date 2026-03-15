import SwiftUI

struct SecuritySidebarView: View {
    @Binding var selectedConnectionID: UUID?
    @Environment(EnvironmentState.self) private var environmentState
    @State private var viewModel = SecuritySidebarViewModel()
    @State private var searchText: String = ""

    private var filteredDbUsers: [SecuritySidebarViewModel.DbUser] {
        if searchText.isEmpty { return viewModel.dbUsers }
        return viewModel.dbUsers.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    private var filteredDbRoles: [SecuritySidebarViewModel.DbRole] {
        if searchText.isEmpty { return viewModel.dbRoles }
        return viewModel.dbRoles.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    private var filteredLogins: [SecuritySidebarViewModel.ServerLogin] {
        if searchText.isEmpty { return viewModel.serverLogins }
        return viewModel.serverLogins.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    private var filteredServerRoles: [SecuritySidebarViewModel.ServerRole] {
        if searchText.isEmpty { return viewModel.serverRoles }
        return viewModel.serverRoles.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search users, roles, logins…", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                Button {
                    Task { await viewModel.reload(for: activeSession) }
                } label: { Image(systemName: "arrow.clockwise") }
                .help("Reload security lists")
            }
            .padding(.horizontal, SpacingTokens.xs)
            .padding(.vertical, SpacingTokens.xxs2)

            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    sectionHeader("Database Users (") { Text("\(viewModel.dbUsers.count)") } suffix: { Text(")") }
                    ForEach(filteredDbUsers) { user in
                        HStack {
                            Image(systemName: "person.fill")
                            Text(user.name).font(TypographyTokens.standard)
                            Spacer()
                            if let schema = user.defaultSchema, !schema.isEmpty {
                                Text(schema).foregroundStyle(ColorTokens.Text.secondary)
                            }
                        }
                        .padding(.horizontal, SpacingTokens.xs)
                        .padding(.vertical, SpacingTokens.xxs)
                    }

                    Divider()

                    sectionHeader("Database Roles (") { Text("\(viewModel.dbRoles.count)") } suffix: { Text(")") }
                    ForEach(filteredDbRoles) { role in
                        HStack {
                            Image(systemName: role.isFixed ? "shield.lefthalf.filled" : "shield")
                            Text(role.name)
                            Spacer()
                            if role.isFixed { Text("fixed").foregroundStyle(ColorTokens.Text.secondary) }
                        }
                        .padding(.horizontal, SpacingTokens.xs)
                        .padding(.vertical, SpacingTokens.xxs)
                    }

                    Divider()

                    sectionHeader("Server Logins (") { Text("\(viewModel.serverLogins.count)") } suffix: { Text(")") }
                    ForEach(filteredLogins) { login in
                        HStack {
                            Image(systemName: login.disabled ? "person.crop.circle.badge.xmark" : "person.crop.circle")
                            Text(login.name)
                            Spacer()
                            Text(login.type).foregroundStyle(ColorTokens.Text.secondary)
                        }
                        .padding(.horizontal, SpacingTokens.xs)
                        .padding(.vertical, SpacingTokens.xxs)
                    }

                    Divider()

                    sectionHeader("Server Roles (") { Text("\(viewModel.serverRoles.count)") } suffix: { Text(")") }
                    ForEach(filteredServerRoles) { role in
                        HStack {
                            Image(systemName: role.isFixed ? "shield.lefthalf.filled" : "shield")
                            Text(role.name)
                            Spacer()
                            if role.isFixed { Text("fixed").foregroundStyle(ColorTokens.Text.secondary) }
                        }
                        .padding(.horizontal, SpacingTokens.xs)
                        .padding(.vertical, SpacingTokens.xxs)
                    }
                }
                .padding(.vertical, SpacingTokens.xs)
            }

            if let message = viewModel.errorMessage {
                Text(message).foregroundStyle(ColorTokens.Text.secondary).padding([.horizontal, .bottom], SpacingTokens.xs)
            }
        }
        .onAppear { Task { await viewModel.reload(for: activeSession) } }
        .onChange(of: selectedConnectionID) {
            Task { await viewModel.reload(for: activeSession) }
        }
    }

    private var activeSession: ConnectionSession? {
        guard let id = selectedConnectionID else { return nil }
        return environmentState.sessionGroup.sessionForConnection(id)
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, @ViewBuilder count: () -> some View, @ViewBuilder suffix: () -> some View) -> some View {
        HStack(spacing: SpacingTokens.xxs) {
            Text(title).font(TypographyTokens.headline)
            count()
            suffix()
            Spacer()
        }
        .padding(.horizontal, SpacingTokens.xs)
    }
}

