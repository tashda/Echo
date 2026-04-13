import Testing
@testable import Echo

@Suite("SyncStartupDecision")
struct SyncStartupDecisionTests {

    @Test func checkpointSuppressesStartupAction() {
        let summary = SyncDataSummary(
            localConnections: 2,
            localIdentities: 1,
            localFolders: 0,
            localBookmarks: 0,
            cloudDocuments: 4
        )

        #expect(summary.startupAction(hasCheckpoint: true) == .none)
    }

    @Test func bothSidesWithNoCheckpointRequiresMergePrompt() {
        let summary = SyncDataSummary(
            localConnections: 1,
            localIdentities: 0,
            localFolders: 0,
            localBookmarks: 0,
            cloudDocuments: 3
        )

        #expect(summary.startupAction(hasCheckpoint: false) == .promptForMerge)
    }

    @Test func cloudOnlyWithNoCheckpointPullsCloud() {
        let summary = SyncDataSummary(
            localConnections: 0,
            localIdentities: 0,
            localFolders: 0,
            localBookmarks: 0,
            cloudDocuments: 2
        )

        #expect(summary.startupAction(hasCheckpoint: false) == .pullCloud)
    }

    @Test func localOnlyWithNoCheckpointUploadsLocal() {
        let summary = SyncDataSummary(
            localConnections: 0,
            localIdentities: 1,
            localFolders: 1,
            localBookmarks: 0,
            cloudDocuments: 0
        )

        #expect(summary.startupAction(hasCheckpoint: false) == .uploadLocal)
    }
}
