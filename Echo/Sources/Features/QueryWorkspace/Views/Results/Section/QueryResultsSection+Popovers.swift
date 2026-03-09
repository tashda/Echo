import SwiftUI

extension QueryResultsSection {
    
    var connectionChipText: String {
        let serverName = connectionDisplayName
        guard let database = effectiveDatabaseName else { return serverName }
        return "\(serverName) • \(database)"
    }

    var connectionDisplayName: String {
        let trimmedName = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty { return trimmedName }
        let trimmedHost = connection.host.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedHost.isEmpty { return trimmedHost }
        return "Server"
    }

    var effectiveDatabaseName: String? {
        if let provided = activeDatabaseName?.trimmingCharacters(in: .whitespacesAndNewlines), !provided.isEmpty {
            return provided
        }
        let fallback = connection.database.trimmingCharacters(in: .whitespacesAndNewlines)
        return fallback.isEmpty ? nil : fallback
    }

#if os(macOS)
    func openJsonInspector(with selection: QueryResultsTableView.JsonSelection) {
        jsonInspectorContext = JsonInspectorContext()
        selectedTab = .jsonInspector
    }

    @ViewBuilder
    func jsonInspectorView() -> some View {
        Text("JSON Inspector")
    }

    struct JsonInspectorContext: Equatable {
        let id = UUID()
    }
#endif
}
