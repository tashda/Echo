import Foundation

extension SyncEngine {
    func nextStartupRequirement() async throws -> (project: Project, summary: SyncDataSummary, action: SyncStartupAction)? {
        guard let projectStore else { return nil }

        for project in projectStore.projects where project.isSyncEnabled {
            let hasCheckpoint = await checkpointStore.hasCheckpoint(for: project.id)
            let summary = try await checkSyncDataSummary(for: project)
            let action = summary.startupAction(hasCheckpoint: hasCheckpoint)
            if action != .none {
                return (project, summary, action)
            }
        }

        return nil
    }

    func hasPendingMergeDecision() async -> Bool {
        do {
            guard let requirement = try await nextStartupRequirement() else { return false }
            return requirement.action == .promptForMerge
        } catch {
            return false
        }
    }
}
