import SwiftUI
import SQLServerKit

extension DatabaseMailSheet {

    // MARK: - Load Data

    func loadData() async {
        guard let mssql = session.session as? MSSQLSession else {
            errorMessage = "Not a SQL Server connection."
            isLoading = false
            return
        }
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
                pendingSettings = [:]
            }

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Feature Management

    func enableFeature() async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isSaving = true
        saveError = nil
        do {
            try await mssql.databaseMail.enableFeature()
            isFeatureEnabled = true
            isSaving = false
            await loadData()
        } catch {
            saveError = error.localizedDescription
            isSaving = false
        }
    }

    func startMail() async {
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

    func stopMail() async {
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

    func createProfile(name: String, description: String?) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isSaving = true
        saveError = nil
        do {
            _ = try await mssql.databaseMail.createProfile(name: name, description: description)
            showAddProfile = false
            isSaving = false
            await loadData()
        } catch {
            saveError = error.localizedDescription
            isSaving = false
        }
    }

    func updateProfile(profileID: Int, name: String, description: String?) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isSaving = true
        saveError = nil
        do {
            try await mssql.databaseMail.updateProfile(profileID: profileID, name: name, description: description)
            editingProfile = nil
            isSaving = false
            await loadData()
        } catch {
            saveError = error.localizedDescription
            isSaving = false
        }
    }

    func deleteProfile(profileID: Int) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isSaving = true
        saveError = nil
        do {
            try await mssql.databaseMail.deleteProfile(profileID: profileID)
            isSaving = false
            await loadData()
        } catch {
            saveError = error.localizedDescription
            isSaving = false
        }
    }

    // MARK: - Account CRUD

    func createAccount(_ config: SQLServerMailAccountConfig) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isSaving = true
        saveError = nil
        do {
            _ = try await mssql.databaseMail.createAccount(config)
            showAddAccount = false
            isSaving = false
            await loadData()
        } catch {
            saveError = error.localizedDescription
            isSaving = false
        }
    }

    func updateAccount(accountID: Int, _ config: SQLServerMailAccountConfig) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isSaving = true
        saveError = nil
        do {
            try await mssql.databaseMail.updateAccount(accountID: accountID, config)
            editingAccount = nil
            isSaving = false
            await loadData()
        } catch {
            saveError = error.localizedDescription
            isSaving = false
        }
    }

    func deleteAccount(accountID: Int) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isSaving = true
        saveError = nil
        do {
            try await mssql.databaseMail.deleteAccount(accountID: accountID)
            isSaving = false
            await loadData()
        } catch {
            saveError = error.localizedDescription
            isSaving = false
        }
    }

    // MARK: - Profile-Account Association

    func linkAccount(profileID: Int, accountID: Int, sequence: Int) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        saveError = nil
        do {
            try await mssql.databaseMail.addAccountToProfile(
                profileID: profileID,
                accountID: accountID,
                sequenceNumber: sequence
            )
            await loadData()
        } catch {
            saveError = error.localizedDescription
        }
    }

    func unlinkAccount(profileID: Int, accountID: Int) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        saveError = nil
        do {
            try await mssql.databaseMail.removeAccountFromProfile(
                profileID: profileID,
                accountID: accountID
            )
            await loadData()
        } catch {
            saveError = error.localizedDescription
        }
    }

    // MARK: - Security

    func grantAccess(profileID: Int, principalName: String, isDefault: Bool) async {
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
            await loadData()
        } catch {
            saveError = error.localizedDescription
            isSaving = false
        }
    }

    func revokeAccess(profileID: Int, principalName: String) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        saveError = nil
        do {
            try await mssql.databaseMail.revokeProfileAccess(
                profileID: profileID,
                principalName: principalName
            )
            await loadData()
        } catch {
            saveError = error.localizedDescription
        }
    }

    // MARK: - Settings

    func applySettings() async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isSaving = true
        saveError = nil
        do {
            for (key, value) in pendingSettings {
                if let original = configParameters.first(where: { $0.name == key }),
                   original.value != value {
                    try await mssql.databaseMail.setConfiguration(parameter: key, value: value)
                }
            }
            isSaving = false
            await loadData()
        } catch {
            saveError = error.localizedDescription
            isSaving = false
        }
    }

    // MARK: - Send Test Email

    func sendTestEmail(profileName: String, recipients: String, subject: String?, body: String?) async {
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
            await loadData()
        } catch {
            saveError = error.localizedDescription
            isSaving = false
        }
    }
}
