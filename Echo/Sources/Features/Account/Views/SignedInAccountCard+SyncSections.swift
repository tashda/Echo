import SwiftUI

extension AccountDetailSheet {

    // MARK: - Sync

    func syncSection(_ engine: SyncEngine) -> some View {
        Section {
            PropertyRow(title: "Status", subtitle: syncStatusDescription(engine)) {
                syncStatusAccessory(engine)
            }

            credentialSyncToggle

            ForEach(SyncCollection.userToggleable, id: \.self) { collection in
                PropertyRow(
                    title: collection.displayName,
                    subtitle: syncCollectionDescription(collection)
                ) {
                    Toggle("", isOn: syncCollectionBinding(for: collection))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }
        } header: {
            Text("Cloud Sync")
        }
    }

    // MARK: - Credential Sync Toggle

    var credentialSyncToggle: some View {
        PropertyRow(title: "Credentials", subtitle: credentialSyncDescription) {
            HStack(spacing: SpacingTokens.xs) {
                if isCheckingEnrollment {
                    ProgressView()
                        .controlSize(.mini)
                } else if e2eManager.isEnrolled && !e2eManager.isUnlocked && SyncPreferences.isCredentialSyncEnabled {
                    Image(systemName: "lock.fill")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }

                Toggle("", isOn: credentialSyncBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Projects

    var projectsSyncSection: some View {
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

    private func syncCollectionDescription(_ collection: SyncCollection) -> String {
        switch collection {
        case .identities:
            if SyncPreferences.isCredentialSyncEnabled {
                return "Saved login names and identity metadata. Passwords are synced through Credentials."
            }
            return "Saved login names and identity metadata. Passwords stay only on this Mac until Credentials is enabled."
        default:
            return collection.displayDescription
        }
    }

    private func syncStatusDescription(_ engine: SyncEngine) -> String {
        switch engine.status {
        case .idle:
            if let lastSync = engine.lastSyncedAt {
                return "Last synced \(lastSync.formatted(.relative(presentation: .named)))"
            }
            if hasSyncEnabledProjects {
                return "Ready to sync your enabled projects."
            }
            return "No projects are currently selected for cloud sync."
        case .syncing:
            return "Syncing your selected projects now."
        case .error(let message):
            return message
        case .offline:
            return "Cloud sync is unavailable while Echo is offline."
        case .disabled:
            return "Sign in to enable cloud sync."
        }
    }

    @ViewBuilder
    private func syncStatusAccessory(_ engine: SyncEngine) -> some View {
        if engine.status.isSyncing {
            ProgressView()
                .controlSize(.small)
        } else {
            Button("Sync Now") {
                Task { await engine.syncNow() }
            }
            .disabled(!hasSyncEnabledProjects)
        }
    }
}
