import SwiftUI
import SQLServerKit

struct DatabaseMailEditorView: View {
    @Bindable var viewModel: DatabaseMailEditorViewModel
    let session: ConnectionSession
    let onDismiss: () -> Void

    @State var selectedPage: DatabaseMailEditorPage? = .profiles
    @State private var navHistory = NavigationHistory<DatabaseMailEditorPage>()

    var canConfigure: Bool {
        session.permissions?.canConfigureDatabaseMail ?? true
    }

    var body: some View {
        NavigationSplitView {
            List(DatabaseMailEditorPage.allCases, id: \.self, selection: $selectedPage) { page in
                Label(page.title, systemImage: page.icon)
                    .tag(page)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            detailContent
                .id(selectedPage)
                .frame(minWidth: 440, minHeight: 400)
                .navigationTitle(navigationTitleText)
                .navigationSubtitle("Database Mail")
                .toolbarTitleDisplayMode(.automatic)
                .navigationHistoryToolbar($selectedPage, history: navHistory)
                .toolbar { toolbarItems }
        }
        .background(PocketSeparatorHider())
        .background(UnsavedChangesGuard(
            hasChanges: viewModel.hasChanges,
            onDiscard: onDismiss
        ))
        .task {
            viewModel.errorMessage = nil
            await viewModel.loadData(session: session)
        }
        .overlay(alignment: .bottom) {
            if let error = viewModel.saveError {
                errorBanner(error)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.saveError)
        .sheet(isPresented: $viewModel.showAddProfile) {
            AddProfileSheet { name, desc in
                await viewModel.createProfile(name: name, description: desc, session: session)
            } onCancel: {
                viewModel.showAddProfile = false
            }
        }
        .sheet(isPresented: $viewModel.showAddAccount) {
            AddAccountSheet { config in
                await viewModel.createAccount(config, session: session)
            } onCancel: {
                viewModel.showAddAccount = false
            }
        }
        .sheet(item: $viewModel.editingAccount) { account in
            EditAccountSheet(account: account) { config in
                await viewModel.updateAccount(accountID: account.accountID, config, session: session)
            } onCancel: {
                viewModel.editingAccount = nil
            }
        }
        .sheet(item: $viewModel.editingProfile) { profile in
            EditProfileSheet(profile: profile) { name, desc in
                await viewModel.updateProfile(profileID: profile.profileID, name: name, description: desc, session: session)
            } onCancel: {
                viewModel.editingProfile = nil
            }
        }
        .sheet(isPresented: $viewModel.showSendTest) {
            SendTestSheet(profiles: viewModel.profiles) { profileName, recipients, subject, body in
                await viewModel.sendTestEmail(profileName: profileName, recipients: recipients, subject: subject, body: body, session: session)
            } onCancel: {
                viewModel.showSendTest = false
            }
        }
        .sheet(isPresented: $viewModel.showGrantAccess) {
            GrantAccessSheet(profiles: viewModel.profiles) { profileID, principalName, isDefault in
                await viewModel.grantAccess(profileID: profileID, principalName: principalName, isDefault: isDefault, session: session)
            } onCancel: {
                viewModel.showGrantAccess = false
            }
        }
        .alert("Delete Profile?", isPresented: deleteProfileBinding) {
            Button("Cancel", role: .cancel) { viewModel.confirmDeleteProfile = nil }
            Button("Delete", role: .destructive) {
                guard let profile = viewModel.confirmDeleteProfile else { return }
                viewModel.confirmDeleteProfile = nil
                Task { await viewModel.deleteProfile(profileID: profile.profileID, session: session) }
            }
        } message: {
            if let profile = viewModel.confirmDeleteProfile {
                Text("Delete profile \"\(profile.name)\"? This cannot be undone.")
            }
        }
        .alert("Delete Account?", isPresented: deleteAccountBinding) {
            Button("Cancel", role: .cancel) { viewModel.confirmDeleteAccount = nil }
            Button("Delete", role: .destructive) {
                guard let account = viewModel.confirmDeleteAccount else { return }
                viewModel.confirmDeleteAccount = nil
                Task { await viewModel.deleteAccount(accountID: account.accountID, session: session) }
            }
        } message: {
            if let account = viewModel.confirmDeleteAccount {
                Text("Delete account \"\(account.name)\"? This cannot be undone.")
            }
        }
    }

    // MARK: - Title

    private var navigationTitleText: String {
        selectedPage?.title ?? "Database Mail"
    }

    // MARK: - Detail Content

    private var isFullPageState: Bool {
        viewModel.isLoading || !viewModel.isFeatureEnabled || viewModel.errorMessage != nil || isCurrentPageEmpty
    }

    private var detailContent: some View {
        Form {
            if !isFullPageState {
                if !canConfigure {
                    PermissionBanner(message: "Database Mail configuration requires the sysadmin role.")
                }
                pageContent
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .overlay {
            if viewModel.isLoading {
                TabInitializingPlaceholder(
                    icon: "envelope",
                    title: "Loading Database Mail",
                    subtitle: "Fetching data from server\u{2026}"
                )
            } else if !viewModel.isFeatureEnabled {
                featureDisabledView
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else if isCurrentPageEmpty {
                pageEmptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Empty Page Detection

    private var isCurrentPageEmpty: Bool {
        switch selectedPage {
        case .profiles: viewModel.profiles.isEmpty
        case .accounts: viewModel.accounts.isEmpty
        case .security: viewModel.principalProfiles.isEmpty
        case .settings: viewModel.configParameters.isEmpty
        case .status: viewModel.status == nil
        case .queue: viewModel.queueItems.isEmpty
        case nil: false
        }
    }

    @ViewBuilder
    private var pageEmptyState: some View {
        switch selectedPage {
        case .profiles:
            ContentUnavailableView {
                Label("No Profiles", systemImage: "person.crop.rectangle.stack")
            } description: {
                Text("No Database Mail profiles configured.")
            }
        case .accounts:
            ContentUnavailableView {
                Label("No Accounts", systemImage: "envelope")
            } description: {
                Text("No Database Mail accounts configured.")
            }
        case .security:
            ContentUnavailableView {
                Label("No Access Grants", systemImage: "lock.shield")
            } description: {
                Text("No profile access grants configured.")
            }
        case .settings:
            ContentUnavailableView {
                Label("No Parameters", systemImage: "gearshape")
            } description: {
                Text("No configuration parameters available.")
            }
        case .status:
            ContentUnavailableView {
                Label("Status Unavailable", systemImage: "power")
            } description: {
                Text("Unable to retrieve Database Mail status.")
            }
        case .queue:
            ContentUnavailableView {
                Label("No Mail Items", systemImage: "tray")
            } description: {
                Text("No items in the mail queue.")
            }
        case nil:
            EmptyView()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    viewModel.showAddProfile = true
                } label: {
                    Label("New Profile", systemImage: "person.crop.rectangle.stack")
                }
                .disabled(!canConfigure)

                Button {
                    viewModel.showAddAccount = true
                } label: {
                    Label("New Account", systemImage: "envelope")
                }
                .disabled(!canConfigure)

                Divider()

                Button {
                    viewModel.showGrantAccess = true
                } label: {
                    Label("Grant Access", systemImage: "lock.shield")
                }
                .disabled(viewModel.profiles.isEmpty || !canConfigure)
            } label: {
                Label("Add", systemImage: "plus")
            }
            .menuIndicator(.hidden)
            .disabled(!viewModel.isFeatureEnabled || viewModel.isLoading)
            .glassEffect(.regular.interactive())
        }
        .sharedBackgroundVisibility(.hidden)

        ToolbarItem(placement: .primaryAction) {
            Button {
                Task { await viewModel.applySettings(session: session) }
            } label: {
                Label("Apply", systemImage: "arrow.right.circle")
            }
            .labelStyle(.iconOnly)
            .disabled(!viewModel.hasChanges || viewModel.isSaving)
            .help("Apply changes without closing")
            .glassEffect(.regular.interactive())
        }
        .sharedBackgroundVisibility(.hidden)

        ToolbarItem(placement: .primaryAction) {
            Button {
                Task {
                    await viewModel.applySettings(session: session)
                    onDismiss()
                }
            } label: {
                Label("Save", systemImage: "checkmark")
            }
            .labelStyle(.iconOnly)
            .disabled(!viewModel.hasChanges || viewModel.isSaving)
            .help("Save and close")
            .glassEffect(.regular.interactive())
        }
        .sharedBackgroundVisibility(.hidden)
    }

    // MARK: - Bindings

    private var deleteProfileBinding: Binding<Bool> {
        Binding(
            get: { viewModel.confirmDeleteProfile != nil },
            set: { if !$0 { viewModel.confirmDeleteProfile = nil } }
        )
    }

    private var deleteAccountBinding: Binding<Bool> {
        Binding(
            get: { viewModel.confirmDeleteAccount != nil },
            set: { if !$0 { viewModel.confirmDeleteAccount = nil } }
        )
    }

    // MARK: - Error Banner

    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ColorTokens.Status.warning)
            Text(error)
                .font(TypographyTokens.formDescription)
                .foregroundStyle(ColorTokens.Text.secondary)
                .lineLimit(1)
        }
        .padding(SpacingTokens.sm)
        .background(.regularMaterial, in: .capsule)
        .padding(.bottom, SpacingTokens.sm)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            Task {
                try? await Task.sleep(for: .seconds(5))
                withAnimation { viewModel.saveError = nil }
            }
        }
    }
}
