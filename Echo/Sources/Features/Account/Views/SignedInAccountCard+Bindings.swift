import SwiftUI

extension AccountDetailSheet {

    // MARK: - Credential Sync Description

    var credentialSyncDescription: String {
        if isCheckingEnrollment {
            return "Checking status…"
        }
        if e2eManager.isEnrolled {
            if e2eManager.isUnlocked {
                return "Passwords encrypted end-to-end"
            } else {
                return "Enter your master password to sync passwords"
            }
        }
        return "Encrypt passwords before syncing"
    }

    // MARK: - Credential Sync Binding

    var credentialSyncBinding: Binding<Bool> {
        Binding(
            get: {
                e2eManager.isEnrolled && SyncPreferences.isCredentialSyncEnabled
            },
            set: { newValue in
                if newValue {
                    if e2eManager.isEnrolled {
                        if e2eManager.isUnlocked {
                            SyncPreferences.setCredentialSyncEnabled(true)
                        } else {
                            showE2EUnlock = true
                        }
                    } else {
                        showE2EEnrollment = true
                    }
                } else {
                    SyncPreferences.setCredentialSyncEnabled(false)
                }
            }
        )
    }

    // MARK: - Project Sync Binding

    func projectSyncBinding(for project: Project) -> Binding<Bool> {
        Binding(
            get: { project.isSyncEnabled },
            set: { newValue in
                if newValue {
                    // Enabling sync — check if server already has data
                    Task { await enableSyncOnProject(project) }
                } else {
                    // Disabling sync — simple toggle
                    guard let store = AppDirector.shared.projectStore as ProjectStore?,
                          var updated = store.projects.first(where: { $0.id == project.id }) else { return }
                    updated.isSyncEnabled = false
                    Task { try? await store.updateProject(updated) }
                }
            }
        )
    }

    /// Enable sync on a project, checking for server data first.
    /// If both local and cloud data exist, shows the merge strategy prompt.
    func enableSyncOnProject(_ project: Project) async {
        guard let syncEngine = AppDirector.shared.syncEngine else { return }

        do {
            let summary = try await syncEngine.checkSyncDataSummary(for: project)

            if summary.needsMergeDecision {
                // Both sides have data — show merge strategy prompt
                mergeStrategySummary = summary
                mergeStrategyProject = project
                showMergeStrategySheet = true
            } else if summary.hasCloudData {
                // Only cloud has data — pull from cloud
                _ = await performSyncWithStrategy(project: project, strategy: .useCloud)
            } else {
                // Only local data or both empty — upload local
                _ = await performSyncWithStrategy(project: project, strategy: .uploadLocal)
            }
        } catch {
            // Fallback: just enable and upload (original behavior)
            _ = await performSyncWithStrategy(project: project, strategy: .uploadLocal)
        }
    }

    // MARK: - Sync Collection Binding

    var hasSyncEnabledProjects: Bool {
        AppDirector.shared.projectStore.projects.contains { $0.isSyncEnabled }
    }

    func syncCollectionBinding(for collection: SyncCollection) -> Binding<Bool> {
        Binding(
            get: { SyncPreferences.isEnabled(collection) },
            set: { SyncPreferences.setEnabled(collection, enabled: $0) }
        )
    }
}
