import Foundation
import Observation
import SwiftUI
import SQLServerKit

@Observable
final class ServerEditorViewModel {
    let connectionSessionID: UUID

    // MARK: - Data State

    var serverInfo: SQLServerServerInfo?
    var systemInfo: SQLServerSystemInfo?
    var securitySettings: SQLServerSecuritySettings?
    var configurations: [SQLServerConfigurationOption] = []

    // MARK: - Pending Changes

    /// Config option name to new value.
    var pendingChanges: [String: Int64] = [:]
    var pendingDataPath: String?
    var pendingLogPath: String?
    var pendingBackupPath: String?

    // MARK: - Loading State

    var isLoading = true
    var isSubmitting = false
    var errorMessage: String?
    var didComplete = false

    // MARK: - Environment

    @ObservationIgnored var activityEngine: ActivityEngine?
    @ObservationIgnored var notificationEngine: NotificationEngine?
    @ObservationIgnored var environmentState: EnvironmentState?

    // MARK: - Computed Properties

    var isFormValid: Bool { true }

    var pages: [ServerEditorPage] { ServerEditorPage.allCases }

    var hasChanges: Bool {
        if !pendingChanges.isEmpty { return true }
        if let pending = pendingDataPath, pending != serverInfo?.instanceDefaultDataPath { return true }
        if let pending = pendingLogPath, pending != serverInfo?.instanceDefaultLogPath { return true }
        if let pending = pendingBackupPath, pending != serverInfo?.instanceDefaultBackupPath { return true }
        return false
    }

    // MARK: - Init

    init(connectionSessionID: UUID) {
        self.connectionSessionID = connectionSessionID
    }

    // MARK: - Helpers

    func configValue(for name: String) -> Int64 {
        pendingChanges[name]
            ?? configurations.first(where: { $0.name == name })?.configuredValue
            ?? 0
    }

    func configBinding(for name: String) -> Binding<Int64> {
        Binding(
            get: { self.configValue(for: name) },
            set: { newValue in
                let original = self.configurations.first(where: { $0.name == name })?.configuredValue ?? 0
                if newValue != original {
                    self.pendingChanges[name] = newValue
                } else {
                    self.pendingChanges.removeValue(forKey: name)
                }
            }
        )
    }

    func configOption(for name: String) -> SQLServerConfigurationOption? {
        configurations.first(where: { $0.name == name })
    }
}
