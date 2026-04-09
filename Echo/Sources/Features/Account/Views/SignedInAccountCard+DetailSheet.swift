import SwiftUI

// MARK: - Account Detail Sheet

struct AccountDetailSheet: View {
    @Bindable var authState: AuthState
    var syncEngine: SyncEngine?
    @Environment(\.dismiss) var dismiss

    @State var isEditingName = false
    @State var editedName = ""
    @State var showDeleteConfirmation = false
    @State var showE2EEnrollment = false
    @State var showE2EUnlock = false
    @State var isCheckingEnrollment = false

    // Merge strategy prompt state
    @State var mergeStrategySummary: SyncDataSummary?
    @State var mergeStrategyProject: Project?
    @State var showMergeStrategySheet = false

    // Credential conflict state
    @State var showCredentialConflictSheet = false

    var e2eManager: E2EEnrollmentManager {
        AppDirector.shared.e2eEnrollmentManager
    }

    var body: some View {
        Form {
            profileSection

            if let syncEngine {
                projectsSyncSection
                syncSection(syncEngine)
            }

            actionsSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(width: 440, height: 700)
        .task { await prepareSheetState() }
        .onChange(of: syncEngine?.pendingCredentialConflicts.count ?? 0) {
            if let conflicts = syncEngine?.pendingCredentialConflicts, !conflicts.isEmpty {
                showCredentialConflictSheet = true
            }
        }
        .sheet(isPresented: $showE2EEnrollment) {
            E2EEnrollmentView(enrollmentManager: e2eManager) {
                await handleCredentialSetupCompletion()
            }
        }
        .sheet(isPresented: $showE2EUnlock) {
            E2EUnlockView(enrollmentManager: e2eManager) {
                await handleCredentialSetupCompletion()
            }
        }
        .sheet(isPresented: $showMergeStrategySheet) {
            if let summary = mergeStrategySummary, let project = mergeStrategyProject {
                SyncMergeStrategySheet(summary: summary, projectName: project.name) { strategy in
                    Task {
                        let succeeded = await performSyncWithStrategy(project: project, strategy: strategy)
                        if succeeded {
                            await presentNextStartupRequirementIfNeeded()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showCredentialConflictSheet) {
            if let conflicts = syncEngine?.pendingCredentialConflicts, !conflicts.isEmpty {
                CredentialConflictSheet(conflicts: conflicts) { useCloud in
                    syncEngine?.resolveAllCredentialConflicts(useCloud: useCloud)
                }
            }
        }
    }

    func prepareSheetState() async {
        await refreshEnrollmentStatus()
        if let conflicts = syncEngine?.pendingCredentialConflicts, !conflicts.isEmpty {
            showCredentialConflictSheet = true
        }
        if e2eManager.isEnrolled && SyncPreferences.isCredentialSyncEnabled && !e2eManager.isUnlocked {
            showE2EUnlock = true
            return
        }
        await presentNextStartupRequirementIfNeeded()
    }

    func refreshEnrollmentStatus() async {
        isCheckingEnrollment = true
        await e2eManager.checkEnrollmentStatus()
        await e2eManager.tryAutoUnlock()
        isCheckingEnrollment = false
    }

    func handleCredentialSetupCompletion() async {
        await presentNextStartupRequirementIfNeeded()
        if !showMergeStrategySheet {
            await syncEngine?.syncNow()
        }
    }

    func presentNextStartupRequirementIfNeeded() async {
        guard let syncEngine else { return }

        do {
            guard let requirement = try await syncEngine.nextStartupRequirement() else { return }
            switch requirement.action {
            case .promptForMerge:
                mergeStrategySummary = requirement.summary
                mergeStrategyProject = requirement.project
                showMergeStrategySheet = true
            case .pullCloud:
                let succeeded = await performSyncWithStrategy(project: requirement.project, strategy: .useCloud)
                if succeeded {
                    await presentNextStartupRequirementIfNeeded()
                }
            case .uploadLocal:
                let succeeded = await performSyncWithStrategy(project: requirement.project, strategy: .uploadLocal)
                if succeeded {
                    await presentNextStartupRequirementIfNeeded()
                }
            case .none:
                break
            }
        } catch {
            return
        }
    }

    func performSyncWithStrategy(project: Project, strategy: SyncMergeStrategy) async -> Bool {
        guard let syncEngine else { return false }
        do {
            // Enable sync on the project first
            if let store = AppDirector.shared.projectStore as ProjectStore?,
               var updated = store.projects.first(where: { $0.id == project.id }) {
                updated.isSyncEnabled = true
                try await store.updateProject(updated)
            }
            try await syncEngine.performInitialUpload(for: project, strategy: strategy)
            return true
        } catch {
            // Error will be reflected in sync status
            return false
        }
    }
}
