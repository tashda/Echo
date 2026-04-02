import Foundation
import SQLServerKit
import Observation

@Observable
final class DatabaseMailEditorViewModel {
    let connectionSessionID: UUID

    // MARK: - Data

    var profiles: [SQLServerMailProfile] = []
    var accounts: [SQLServerMailAccount] = []
    var profileAccounts: [SQLServerMailProfileAccount] = []
    var principalProfiles: [SQLServerMailPrincipalProfile] = []
    var configParameters: [SQLServerMailConfigParameter] = []
    var status: SQLServerMailStatus?
    var queueItems: [SQLServerMailQueueItem] = []
    var eventLogEntries: [SQLServerMailEventLogEntry] = []
    var isFeatureEnabled = true

    // MARK: - Loading State

    var isLoading = true
    var errorMessage: String?

    // MARK: - Action State

    var isSaving = false
    var saveError: String?
    var pendingSettings: [String: String] = [:]

    // MARK: - Sheet State

    var showAddProfile = false
    var showAddAccount = false
    var editingAccount: SQLServerMailAccount?
    var editingProfile: SQLServerMailProfile?
    var showSendTest = false
    var showGrantAccess = false

    // MARK: - Delete Confirmation

    var confirmDeleteProfile: SQLServerMailProfile?
    var confirmDeleteAccount: SQLServerMailAccount?

    // MARK: - Submit State

    var isSubmitting = false
    var didComplete = false

    // MARK: - ActivityEngine

    @ObservationIgnored var activityEngine: ActivityEngine?

    // MARK: - Dirty Tracking

    @ObservationIgnored internal var settingsSnapshot: [String: String] = [:]

    var hasChanges: Bool {
        hasSettingsChanges
    }

    var hasSettingsChanges: Bool {
        for (key, value) in pendingSettings {
            if let original = configParameters.first(where: { $0.name == key }),
               original.value != value {
                return true
            }
        }
        return false
    }

    // MARK: - Init

    init(connectionSessionID: UUID) {
        self.connectionSessionID = connectionSessionID
    }

}
