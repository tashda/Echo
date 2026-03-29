import Foundation
import MySQLKit

extension ServerPropertiesViewModel {
    func loadStatusVariables(mysql: MySQLSession) async {
        isLoading = true
        defer { isLoading = false }
        let handle = activityEngine?.begin("Loading server status variables", connectionSessionID: connectionSessionID)
        do {
            statusVariables = try await mysql.client.admin.globalStatus()
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .map {
                    PropertyItem(
                        id: $0.name,
                        name: $0.name,
                        value: $0.value,
                        category: variableCategory(for: $0.name)
                    )
                }
            handle?.succeed()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to load server status variables: \(error.localizedDescription)", severity: .error)
        }
    }
}
