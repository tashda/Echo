import Foundation

extension WorkspaceTabContainerView {
    func recordQueryHistory(sql: String, tab: WorkspaceTab, state: QueryEditorState,
                            resultCount: Int? = nil, outcome: String? = nil) {
        let connection = environmentState.connectionStore.connections.first { $0.id == tab.connection.id } ?? tab.connection
        appState.addToQueryHistory(sql, connectionID: connection.id,
                                  databaseName: tab.activeDatabaseName ?? connection.database,
                                  resultCount: resultCount, duration: state.lastExecutionTime,
                                  outcome: outcome, connectionName: connection.connectionName.isEmpty ? connection.host : connection.connectionName,
                                  keepsHistory: connection.keepsQueryHistory)
    }
}
