import Foundation
import SQLServerKit

// MARK: - MSSQL Apply Operations

extension DatabaseEditorViewModel {

    func applyMSSQLOption(_ option: SQLServerDatabaseOption, session: ConnectionSession) async {
        guard let mssqlSession = session.session as? MSSQLSession else { return }
        let admin = mssqlSession.admin
        isSaving = true
        statusMessage = nil

        do {
            let messages = try await admin.alterDatabaseOption(name: databaseName, option: option)
            let info = messages.filter { $0.kind == .info }.map(\.message).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            isSaving = false
            if !info.isEmpty { statusMessage = info }
            await environmentState?.refreshDatabaseStructure(for: session.id)
        } catch {
            isSaving = false
            statusMessage = error.localizedDescription
            notificationEngine?.post(category: .databasePropertiesError, message: error.localizedDescription)
        }
    }

    func applyMSSQLFileOption(file: SQLServerDatabaseFile, option: SQLServerDatabaseFileOption, session: ConnectionSession) async {
        guard let mssqlSession = session.session as? MSSQLSession else { return }
        let admin = mssqlSession.admin
        isSaving = true
        statusMessage = nil

        do {
            let messages = try await admin.modifyDatabaseFile(
                databaseName: databaseName,
                logicalFileName: file.name,
                option: option
            )
            let info = messages.filter { $0.kind == .info }.map(\.message).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            isSaving = false
            if !info.isEmpty { statusMessage = info }
            if let updatedSession = session.session as? MSSQLSession {
                mssqlFiles = (try? await updatedSession.admin.fetchDatabaseFiles(name: databaseName)) ?? mssqlFiles
            }
        } catch {
            isSaving = false
            statusMessage = error.localizedDescription
            notificationEngine?.post(category: .databasePropertiesError, message: error.localizedDescription)
        }
    }

    func applyQueryStoreOption(_ option: SQLServerQueryStoreOption, session: ConnectionSession) async {
        guard let mssqlSession = session.session as? MSSQLSession else { return }
        let queryStoreClient = mssqlSession.queryStore
        isSaving = true
        statusMessage = nil

        do {
            try await queryStoreClient.alterOption(database: databaseName, option: option)
            isSaving = false
            let updated = try await queryStoreClient.options(database: databaseName)
            populateQueryStoreState(updated)
        } catch {
            isSaving = false
            statusMessage = error.localizedDescription
        }
    }

    func updateScopedConfigValue(configurationID: Int, newValue: String) {
        guard let index = scopedConfigurations.firstIndex(where: { $0.configurationID == configurationID }) else { return }
        let old = scopedConfigurations[index]
        scopedConfigurations[index] = SQLServerScopedConfiguration(
            configurationID: old.configurationID,
            name: old.name,
            value: newValue,
            valueForSecondary: old.valueForSecondary
        )
    }

    func applyScopedConfiguration(name: String, value: String, session: ConnectionSession) async {
        guard let mssqlSession = session.session as? MSSQLSession else { return }
        let admin = mssqlSession.admin
        isSaving = true
        statusMessage = nil

        do {
            _ = try await admin.alterScopedConfiguration(database: databaseName, name: name, value: value)
            isSaving = false
            // Reload scoped configs to reflect the change
            scopedConfigurations = (try? await admin.listScopedConfigurations(database: databaseName)) ?? scopedConfigurations
        } catch {
            isSaving = false
            statusMessage = error.localizedDescription
            notificationEngine?.post(category: .databasePropertiesError, message: error.localizedDescription)
        }
    }

    func applyFileGrowthChange(index: Int, file: SQLServerDatabaseFile, session: ConnectionSession) async {
        let growthType = fileGrowthTypes[index] ?? (file.isPercentGrowth ? FileGrowthType.percent : .mb)
        let value = fileGrowthValues[index] ?? (file.isPercentGrowth ? file.growthPercent ?? 10 : file.growthMB ?? 64)
        switch growthType {
        case .mb:
            await applyMSSQLFileOption(file: file, option: .filegrowthMB(value), session: session)
        case .percent:
            await applyMSSQLFileOption(file: file, option: .filegrowthPercent(value), session: session)
        case .none:
            await applyMSSQLFileOption(file: file, option: .filegrowthNone, session: session)
        }
    }
}
