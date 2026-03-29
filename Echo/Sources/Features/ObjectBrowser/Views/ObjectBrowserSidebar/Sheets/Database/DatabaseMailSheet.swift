import SwiftUI
import SQLServerKit

/// Full configuration panel for Database Mail — profiles, accounts, security, settings, and queue.
struct DatabaseMailSheet: View {
    let session: ConnectionSession
    let onDismiss: () -> Void

    @State var selectedPage: MailPage = .profiles
    @State var isLoading = true
    @State var errorMessage: String?

    // Data
    @State var profiles: [SQLServerMailProfile] = []
    @State var accounts: [SQLServerMailAccount] = []
    @State var profileAccounts: [SQLServerMailProfileAccount] = []
    @State var principalProfiles: [SQLServerMailPrincipalProfile] = []
    @State var configParameters: [SQLServerMailConfigParameter] = []
    @State var status: SQLServerMailStatus?
    @State var queueItems: [SQLServerMailQueueItem] = []
    @State var isFeatureEnabled = true

    // Sheet state
    @State var showAddProfile = false
    @State var showAddAccount = false
    @State var editingAccount: SQLServerMailAccount?
    @State var editingProfile: SQLServerMailProfile?
    @State var showSendTest = false
    @State var showGrantAccess = false

    // Action state
    @State var isSaving = false
    @State var saveError: String?
    @State var pendingSettings: [String: String] = [:]

    // Delete confirmation
    @State var confirmDeleteProfile: SQLServerMailProfile?
    @State var confirmDeleteAccount: SQLServerMailAccount?

    /// Whether the current user can configure Database Mail (sysadmin only).
    /// Fail-open: if permissions haven't loaded, assume enabled.
    var canConfigure: Bool {
        session.permissions?.canConfigureDatabaseMail ?? true
    }

    enum MailPage: String, CaseIterable {
        case profiles = "Profiles"
        case accounts = "Accounts"
        case security = "Security"
        case settings = "Settings"
        case queue = "Mail Queue"

        var icon: String {
            switch self {
            case .profiles: "person.crop.rectangle.stack"
            case .accounts: "envelope"
            case .security: "lock.shield"
            case .settings: "gearshape"
            case .queue: "tray"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !canConfigure {
                PermissionBanner(message: "Database Mail configuration requires the sysadmin role.")
            }
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 160)
                Divider()
                detailPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()
            footerBar
        }
        .frame(minWidth: 640, minHeight: 480)
        .frame(idealWidth: 720, idealHeight: 540)
        .task { await loadData() }
        .alert("Delete Profile?", isPresented: deleteProfileBinding) {
            Button("Cancel", role: .cancel) { confirmDeleteProfile = nil }
            Button("Delete", role: .destructive) {
                guard let profile = confirmDeleteProfile else { return }
                confirmDeleteProfile = nil
                Task { await deleteProfile(profileID: profile.profileID) }
            }
        } message: {
            if let profile = confirmDeleteProfile {
                Text("Delete profile \"\(profile.name)\"? This cannot be undone.")
            }
        }
        .alert("Delete Account?", isPresented: deleteAccountBinding) {
            Button("Cancel", role: .cancel) { confirmDeleteAccount = nil }
            Button("Delete", role: .destructive) {
                guard let account = confirmDeleteAccount else { return }
                confirmDeleteAccount = nil
                Task { await deleteAccount(accountID: account.accountID) }
            }
        } message: {
            if let account = confirmDeleteAccount {
                Text("Delete account \"\(account.name)\"? This cannot be undone.")
            }
        }
        .sheet(isPresented: $showAddProfile) {
            AddProfileSheet { name, desc in
                await createProfile(name: name, description: desc)
            } onCancel: {
                showAddProfile = false
            }
        }
        .sheet(isPresented: $showAddAccount) {
            AddAccountSheet { config in
                await createAccount(config)
            } onCancel: {
                showAddAccount = false
            }
        }
        .sheet(item: $editingAccount) { account in
            EditAccountSheet(account: account) { config in
                await updateAccount(accountID: account.accountID, config)
            } onCancel: {
                editingAccount = nil
            }
        }
        .sheet(item: $editingProfile) { profile in
            EditProfileSheet(profile: profile) { name, desc in
                await updateProfile(profileID: profile.profileID, name: name, description: desc)
            } onCancel: {
                editingProfile = nil
            }
        }
        .sheet(isPresented: $showSendTest) {
            SendTestSheet(profiles: profiles) { profileName, recipients, subject, body in
                await sendTestEmail(profileName: profileName, recipients: recipients, subject: subject, body: body)
            } onCancel: {
                showSendTest = false
            }
        }
        .sheet(isPresented: $showGrantAccess) {
            GrantAccessSheet(profiles: profiles) { profileID, principalName, isDefault in
                await grantAccess(profileID: profileID, principalName: principalName, isDefault: isDefault)
            } onCancel: {
                showGrantAccess = false
            }
        }
    }

    private var sidebar: some View {
        List(MailPage.allCases, id: \.self, selection: $selectedPage) { page in
            Label(page.rawValue, systemImage: page.icon)
                .tag(page)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .contentMargins(SpacingTokens.xs)
    }

    @ViewBuilder
    private var detailPane: some View {
        if isLoading {
            VStack { Spacer(); ProgressView("Loading Database Mail\u{2026}"); Spacer() }
        } else if !isFeatureEnabled {
            featureDisabledView
        } else if let error = errorMessage {
            VStack {
                Spacer()
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(ColorTokens.Text.secondary)
                Spacer()
            }
            .padding()
        } else {
            pageContent
        }
    }

    private var featureDisabledView: some View {
        VStack(spacing: SpacingTokens.md) {
            Spacer()
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(TypographyTokens.iconLarge)
                .foregroundStyle(ColorTokens.Text.tertiary)
            Text("Database Mail is not enabled")
                .font(TypographyTokens.prominent.weight(.medium))
            Text("Database Mail XPs must be enabled on the server before you can configure mail.")
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            if canConfigure && !isSaving {
                Button("Enable Database Mail") {
                    Task { await enableFeature() }
                }
                .buttonStyle(.bordered)
            } else if canConfigure {
                Button("Enable Database Mail") {}
                    .buttonStyle(.bordered)
                    .disabled(true)
            } else {
                Text("Contact your server administrator to enable Database Mail.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
            Spacer()
        }
        .padding()
    }

    @ViewBuilder
    var pageContent: some View {
        switch selectedPage {
        case .profiles: profilesPage
        case .accounts: accountsPage
        case .security: securityPage
        case .settings: settingsPage
        case .queue: queuePage
        }
    }

    private var footerBar: some View {
        HStack {
            if let status {
                Circle()
                    .fill(status.isStarted ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text("Database Mail: \(status.statusDescription)")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)

                Button(status.isStarted ? "Stop" : "Start") {
                    Task {
                        if status.isStarted {
                            await stopMail()
                        } else {
                            await startMail()
                        }
                    }
                }
                .controlSize(.small)
                .disabled(isSaving || !canConfigure)
                .help(canConfigure ? "" : "Requires sysadmin role")
            }

            if !profiles.isEmpty {
                Button("Send Test Email\u{2026}") {
                    showSendTest = true
                }
                .controlSize(.small)
                .disabled(!canConfigure)
                .help(canConfigure ? "" : "Requires sysadmin role")
            }

            if let error = saveError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(ColorTokens.Status.warning)
                Text(error)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button("Done") { onDismiss() }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
        }
        .padding(SpacingTokens.md)
    }

    var deleteProfileBinding: Binding<Bool> {
        Binding(get: { confirmDeleteProfile != nil }, set: { if !$0 { confirmDeleteProfile = nil } })
    }

    var deleteAccountBinding: Binding<Bool> {
        Binding(get: { confirmDeleteAccount != nil }, set: { if !$0 { confirmDeleteAccount = nil } })
    }
}
