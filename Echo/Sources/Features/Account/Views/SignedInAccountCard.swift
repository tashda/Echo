import SwiftUI

/// Apple ID-style account row in General settings.
/// Shows avatar + name + chevron. Clicking opens a detail sheet.
struct SignedInAccountCard: View {
    @Bindable var authState: AuthState
    var syncEngine: SyncEngine?

    @State private var showAccountSheet = false

    var body: some View {
        Section {
            accountRow
        } header: {
            Text("Echo Account")
        }
        .sheet(isPresented: $showAccountSheet) {
            AccountDetailSheet(authState: authState, syncEngine: syncEngine)
        }
    }

    // MARK: - Clickable Row

    private var accountRow: some View {
        Button {
            showAccountSheet = true
        } label: {
            HStack(spacing: SpacingTokens.md) {
                accountAvatar

                VStack(alignment: .leading, spacing: 2) {
                    Text(authState.currentUser?.displayName ?? "Echo User")
                        .font(TypographyTokens.prominent)
                        .foregroundStyle(ColorTokens.Text.primary)

                    if let email = authState.currentUser?.email {
                        Text(email)
                            .font(TypographyTokens.formDescription)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }

                    syncSummary
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTokens.Text.quaternary)
            }
            .padding(.vertical, SpacingTokens.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sync Summary (inline, one line)

    @ViewBuilder
    private var syncSummary: some View {
        if let engine = syncEngine {
            HStack(spacing: 4) {
                switch engine.status {
                case .idle:
                    if let lastSync = engine.lastSyncedAt {
                        Image(systemName: "checkmark.icloud")
                            .foregroundStyle(ColorTokens.Status.success)
                        Text("Synced \(lastSync, format: .relative(presentation: .named))")
                    } else {
                        Image(systemName: "icloud")
                            .foregroundStyle(ColorTokens.Text.tertiary)
                        Text("Sync available")
                    }
                case .syncing:
                    ProgressView()
                        .controlSize(.mini)
                    Text("Syncing…")
                case .error:
                    Image(systemName: "exclamationmark.icloud")
                        .foregroundStyle(ColorTokens.Status.error)
                    Text("Sync error — tap to retry")
                case .offline:
                    Image(systemName: "icloud.slash")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                    Text("Offline")
                case .disabled:
                    Image(systemName: "icloud.slash")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                    Text("Sync disabled")
                }
            }
            .font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.Text.tertiary)
        }
    }

    // MARK: - Avatar

    @ViewBuilder
    private var accountAvatar: some View {
        if let avatarURL = authState.currentUser?.avatarURL {
            AsyncImage(url: avatarURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                default:
                    initialsAvatar
                }
            }
        } else {
            initialsAvatar
        }
    }

    private var initialsAvatar: some View {
        ZStack {
            Circle()
                .fill(.quaternary)
                .frame(width: 48, height: 48)

            Text(avatarInitials)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(ColorTokens.Text.secondary)
        }
    }

    private var avatarInitials: String {
        let name = authState.currentUser?.displayName
            ?? authState.currentUser?.email
            ?? "U"
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Account Detail Sheet

private struct AccountDetailSheet: View {
    @Bindable var authState: AuthState
    var syncEngine: SyncEngine?
    @Environment(\.dismiss) private var dismiss

    @State private var isEditingName = false
    @State private var editedName = ""
    @State private var showDeleteConfirmation = false
    @State private var showE2EEnrollment = false
    @State private var showE2EUnlock = false

    var body: some View {
        Form {
            profileSection

            if let syncEngine {
                projectsSyncSection
                syncSection(syncEngine)
                credentialSyncSection
            }

            actionsSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(width: 440, height: 700)
        .sheet(isPresented: $showE2EEnrollment) {
            E2EEnrollmentView(enrollmentManager: AppDirector.shared.e2eEnrollmentManager)
        }
        .sheet(isPresented: $showE2EUnlock) {
            E2EUnlockView(enrollmentManager: AppDirector.shared.e2eEnrollmentManager)
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        Section("Profile") {
            // Name
            if isEditingName {
                HStack {
                    TextField("", text: $editedName, prompt: Text("Your name"))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { saveDisplayName() }

                    Button("Save") { saveDisplayName() }
                        .buttonStyle(.bordered)
                        .keyboardShortcut(.defaultAction)
                        .controlSize(.small)
                        .disabled(editedName.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button("Cancel") { isEditingName = false }
                        .controlSize(.small)
                }
            } else {
                LabeledContent("Name") {
                    HStack(spacing: SpacingTokens.xs) {
                        Text(authState.currentUser?.displayName ?? "Not set")
                            .foregroundStyle(authState.currentUser?.displayName != nil ? ColorTokens.Text.primary : ColorTokens.Text.tertiary)
                        Button {
                            editedName = authState.currentUser?.displayName ?? ""
                            isEditingName = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 11))
                                .foregroundStyle(ColorTokens.Text.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Email
            if let email = authState.currentUser?.email {
                LabeledContent("Email", value: email)
            }

            // Auth Method
            if let method = authState.currentUser?.authMethod {
                LabeledContent("Sign-in method") {
                    HStack(spacing: 4) {
                        authMethodIcon(method)
                        Text(method.displayName)
                    }
                }
            }
        }
    }

    // MARK: - Sync

    private func syncSection(_ engine: SyncEngine) -> some View {
        Section("Cloud Sync") {
            // Status + Sync Now
            HStack {
                Label {
                    switch engine.status {
                    case .idle:
                        if let lastSync = engine.lastSyncedAt {
                            Text("Last synced \(lastSync, format: .relative(presentation: .named))")
                        } else if hasSyncEnabledProjects {
                            Text("Sync enabled")
                        } else {
                            Text("No projects synced")
                        }
                    case .syncing:
                        Text("Syncing…")
                    case .error(let message):
                        Text(message)
                            .lineLimit(2)
                    case .offline:
                        Text("Offline")
                    case .disabled:
                        Text("Sync disabled")
                    }
                } icon: {
                    switch engine.status {
                    case .idle:
                        Image(systemName: "checkmark.icloud")
                            .foregroundStyle(ColorTokens.Status.success)
                    case .syncing:
                        ProgressView()
                            .controlSize(.small)
                    case .error:
                        Image(systemName: "exclamationmark.icloud")
                            .foregroundStyle(ColorTokens.Status.error)
                    case .offline, .disabled:
                        Image(systemName: "icloud.slash")
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                }
                .font(TypographyTokens.formDescription)
                .foregroundStyle(engine.status.isError ? ColorTokens.Status.error : ColorTokens.Text.secondary)

                Spacer()

                Button("Sync Now") {
                    Task { await engine.syncNow() }
                }
                .font(TypographyTokens.formDescription)
                .disabled(engine.status.isSyncing)
            }

            // Collection toggles
            ForEach(SyncCollection.userToggleable, id: \.self) { collection in
                Toggle(isOn: syncCollectionBinding(for: collection)) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(collection.displayName)
                            Text(collection.displayDescription)
                                .font(TypographyTokens.detail)
                                .foregroundStyle(ColorTokens.Text.tertiary)
                        }
                    } icon: {
                        Image(systemName: collection.systemImage)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Projects

    private var projectsSyncSection: some View {
        Section("Projects") {
            let projects = AppDirector.shared.projectStore.projects
            if projects.isEmpty {
                Text("No projects")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            } else {
                ForEach(projects) { project in
                    Toggle(isOn: projectSyncBinding(for: project)) {
                        Label {
                            Text(project.name)
                        } icon: {
                            Image(systemName: project.iconName ?? "folder.fill")
                                .foregroundStyle(project.color)
                        }
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
            }
        }
    }

    private func projectSyncBinding(for project: Project) -> Binding<Bool> {
        Binding(
            get: { project.isSyncEnabled },
            set: { newValue in
                guard let store = AppDirector.shared.projectStore as ProjectStore?,
                      var updated = store.projects.first(where: { $0.id == project.id }) else { return }
                updated.isSyncEnabled = newValue
                Task {
                    try? await store.updateProject(updated)
                    if newValue, let syncEngine = AppDirector.shared.syncEngine {
                        try? await syncEngine.performInitialUpload(for: updated)
                    }
                }
            }
        )
    }

    private var hasSyncEnabledProjects: Bool {
        AppDirector.shared.projectStore.projects.contains { $0.isSyncEnabled }
    }

    private func syncCollectionBinding(for collection: SyncCollection) -> Binding<Bool> {
        Binding(
            get: { SyncPreferences.isEnabled(collection) },
            set: { SyncPreferences.setEnabled(collection, enabled: $0) }
        )
    }

    // MARK: - Actions

    private var actionsSection: some View {
        Section {
            HStack {
                Button("Sign Out") {
                    Task {
                        await authState.signOut()
                        dismiss()
                    }
                }

                Spacer()

                Button("Delete Account", role: .destructive) {
                    showDeleteConfirmation = true
                }
                .font(TypographyTokens.formDescription)
            }
            .alert("Delete Account", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    Task {
                        try? await authState.deleteAccount()
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete your account and all synced data. This action cannot be undone.")
            }
        }
    }

    // MARK: - Credential Sync (E2E)

    private var credentialSyncSection: some View {
        let manager = AppDirector.shared.e2eEnrollmentManager
        return Section("Credential Sync") {
            if manager.isEnrolled {
                if manager.isUnlocked {
                    Label {
                        Text("Passwords encrypted and synced")
                    } icon: {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(ColorTokens.Status.success)
                    }
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
                } else {
                    HStack {
                        Label {
                            Text("Locked — enter master password")
                        } icon: {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(ColorTokens.Text.tertiary)
                        }
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)

                        Spacer()

                        Button("Unlock") { showE2EUnlock = true }
                            .font(TypographyTokens.formDescription)
                    }
                }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("End-to-end encryption")
                            .font(TypographyTokens.formDescription)
                        Text("Encrypt database passwords before syncing")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }

                    Spacer()

                    Button("Set Up") { showE2EEnrollment = true }
                        .font(TypographyTokens.formDescription)
                }
            }
        }
    }

    // MARK: - Auth Method Icon

    @ViewBuilder
    private func authMethodIcon(_ method: AuthMethod) -> some View {
        switch method {
        case .google:
            Image("GoogleLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 13, height: 13)
        case .apple:
            Image(systemName: "apple.logo")
                .font(.system(size: 11))
        case .email:
            Image(systemName: "envelope.fill")
                .font(.system(size: 11))
        }
    }

    // MARK: - Helpers

    private func saveDisplayName() {
        let name = editedName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        isEditingName = false
        Task { await authState.updateDisplayName(name) }
    }
}
