import Foundation
import SQLServerKit

// MARK: - Data Loading

extension ServerEditorViewModel {

    func loadProperties(session: ConnectionSession) async {
        guard let adapter = session.session as? SQLServerSessionAdapter else {
            errorMessage = "Server properties are only available for SQL Server connections."
            isLoading = false
            return
        }

        let serverConfig = adapter.client.serverConfig

        do {
            async let infoTask = serverConfig.fetchServerInfo()
            async let systemTask = serverConfig.fetchSystemInfo()
            async let securityTask = serverConfig.fetchSecuritySettings()
            async let configsTask = serverConfig.listConfigurations(showAdvanced: true)
            async let startupTask = serverConfig.fetchStartupParameters()

            let (info, system, security, configs, startup) = try await (
                infoTask, systemTask, securityTask, configsTask, startupTask
            )

            serverInfo = info
            systemInfo = system
            securitySettings = security
            configurations = configs
            startupParameters = startup
            isLoading = false
        } catch {
            let raw = error.localizedDescription
            if raw.contains("permission denied") || raw.contains("does not have permission") {
                errorMessage = "Insufficient permissions to read server properties."
            } else {
                errorMessage = raw
            }
            isLoading = false
        }
    }
}
