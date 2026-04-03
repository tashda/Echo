import Foundation
import SQLServerKit

extension DatabaseMailEditorViewModel {

    // MARK: - Load Data

    func loadData(session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else {
            errorMessage = "Not a SQL Server connection."
            isLoading = false
            return
        }
        let handle = activityEngine?.begin("Loading Database Mail", connectionSessionID: connectionSessionID)
        do {
            let enabled = try await mssql.databaseMail.isFeatureEnabled()
            isFeatureEnabled = enabled

            if enabled {
                profiles = try await mssql.databaseMail.listProfiles()
                accounts = try await mssql.databaseMail.listAccounts()
                profileAccounts = try await mssql.databaseMail.listProfileAccounts()
                principalProfiles = try await mssql.databaseMail.listPrincipalProfiles()
                configParameters = try await mssql.databaseMail.configuration()
                status = try await mssql.databaseMail.status()
                queueItems = try await mssql.databaseMail.mailQueue(limit: 50)
                eventLogEntries = try await mssql.databaseMail.eventLog(limit: 25)
                pendingSettings = [:]
                takeSettingsSnapshot()
            }

            isLoading = false
            handle?.succeed()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            handle?.fail(error.localizedDescription)
        }
    }

    // MARK: - Feature Management

    func enableFeature(session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isSaving = true
        saveError = nil
        do {
            try await mssql.databaseMail.enableFeature()
            isFeatureEnabled = true
            isSaving = false
            await loadData(session: session)
        } catch {
            saveError = error.localizedDescription
            isSaving = false
        }
    }

    func startMail(session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isSaving = true
        saveError = nil
        do {
            try await mssql.databaseMail.start()
            status = try await mssql.databaseMail.status()
            isSaving = false
        } catch {
            saveError = error.localizedDescription
            isSaving = false
        }
    }

    func stopMail(session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isSaving = true
        saveError = nil
        do {
            try await mssql.databaseMail.stop()
            status = try await mssql.databaseMail.status()
            isSaving = false
        } catch {
            saveError = error.localizedDescription
            isSaving = false
        }
    }

    // MARK: - Profile CRUD

    func createProfile(name: String, description: String?, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isSaving = true
        saveError = nil
        do {
            _ = try await mssql.databaseMail.createProfile(name: name, description: description)
            showAddProfile = false
            isSaving = false
            await loadData(session: session)
        } catch {
            saveError = error.localizedDescription
            isSaving = false
        }
    }

    func updateProfile(profileID: Int, name: String, description: String?, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isSaving = true
        saveError = nil
        do {
            try await mssql.databaseMail.updateProfile(profileID: profileID, name: name, description: description)
            editingProfile = nil
            isSaving = false
            await loadData(session: session)
        } catch {
            saveError = error.localizedDescription
            isSaving = false
        }
    }

    func deleteProfile(profileID: Int, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isSaving = true
        saveError = nil
        do {
            try await mssql.databaseMail.deleteProfile(profileID: profileID)
            isSaving = false
            await loadData(session: session)
        } catch {
            saveError = error.localizedDescription
            isSaving = false
        }
    }

    // MARK: - Account CRUD

    func createAccount(_ config: SQLServerMailAccountConfig, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isSaving = true
        saveError = nil
        do {
            _ = try await mssql.databaseMail.createAccount(config)
            showAddAccount = false
            isSaving = false
            await loadData(session: session)
        } catch {
            saveError = error.localizedDescription
            isSaving = false
        }
    }

    func updateAccount(accountID: Int, _ config: SQLServerMailAccountConfig, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isSaving = true
        saveError = nil
        do {
            try await mssql.databaseMail.updateAccount(accountID: accountID, config)
            editingAccount = nil
            isSaving = false
            await loadData(session: session)
        } catch {
            saveError = error.localizedDescription
            isSaving = false
        }
    }

    func deleteAccount(accountID: Int, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isSaving = true
        saveError = nil
        do {
            try await mssql.databaseMail.deleteAccount(accountID: accountID)
            isSaving = false
            await loadData(session: session)
        } catch {
            saveError = error.localizedDescription
            isSaving = false
        }
    }

    // MARK: - Profile-Account Association

    func linkAccount(profileID: Int, accountID: Int, sequence: Int, session: ConnectionSession) async {
        saveError = nil
        guard let mssql = session.session as? MSSQLSession else { return }
        do {
            try await mssql.databaseMail.addAccountToProfile(
                profileID: profileID,
                accountID: accountID,
                sequenceNumber: sequence
            )
            await loadData(session: session)
        } catch {
            saveError = error.localizedDescription
        }
    }

    func unlinkAccount(profileID: Int, accountID: Int, session: ConnectionSession) async {
        saveError = nil
        guard let mssql = session.session as? MSSQLSession else { return }
        do {
            try await mssql.databaseMail.removeAccountFromProfile(
                profileID: profileID,
                accountID: accountID
            )
            await loadData(session: session)
        } catch {
            saveError = error.localizedDescription
        }
    }

    // MARK: - Security

    func grantAccess(profileID: Int, principalName: String, isDefault: Bool, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isSaving = true
        saveError = nil
        do {
            try await mssql.databaseMail.grantProfileAccess(
                profileID: profileID,
                principalName: principalName,
                isDefault: isDefault
            )
            showGrantAccess = false
            isSaving = false
            await loadData(session: session)
        } catch {
            saveError = error.localizedDescription
            isSaving = false
        }
    }

    func revokeAccess(profileID: Int, principalName: String, session: ConnectionSession) async {
        saveError = nil
        guard let mssql = session.session as? MSSQLSession else { return }
        do {
            try await mssql.databaseMail.revokeProfileAccess(
                profileID: profileID,
                principalName: principalName
            )
            await loadData(session: session)
        } catch {
            saveError = error.localizedDescription
        }
    }

    // MARK: - Settings

    func applySettings(session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isSaving = true
        saveError = nil
        let handle = activityEngine?.begin("Saving Database Mail Settings", connectionSessionID: connectionSessionID)
        do {
            for (key, value) in pendingSettings {
                if let original = configParameters.first(where: { $0.name == key }),
                   original.value != value {
                    try await mssql.databaseMail.setConfiguration(parameter: key, value: value)
                }
            }
            isSaving = false
            handle?.succeed()
            await loadData(session: session)
        } catch {
            saveError = error.localizedDescription
            isSaving = false
            handle?.fail(error.localizedDescription)
        }
    }

    // MARK: - Send Test Email

    func sendTestEmail(profileName: String, recipients: String, subject: String?, body: String?, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isSaving = true
        saveError = nil
        do {
            try await mssql.databaseMail.sendTestEmail(
                profileName: profileName,
                recipients: recipients,
                subject: subject,
                body: body
            )
            showSendTest = false
            isSaving = false
            await loadData(session: session)
        } catch {
            saveError = error.localizedDescription
            isSaving = false
        }
    }

    // MARK: - Snapshot

    private func takeSettingsSnapshot() {
        settingsSnapshot = Dictionary(
            configParameters.map { ($0.name, $0.value) },
            uniquingKeysWith: { a, _ in a }
        )
    }
}
