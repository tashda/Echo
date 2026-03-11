import Foundation
import Combine
import SwiftUI

@MainActor
final class PSQLTabViewModel: ObservableObject, Identifiable {
    let id = UUID()
    let connection: SavedConnection
    let session: DatabaseSession
    let database: String
    
    @Published var history: String = ""
    @Published var input: String = ""
    @Published var isExecuting: Bool = false

    init(connection: SavedConnection, session: DatabaseSession, database: String? = nil) {
        self.connection = connection
        self.session = session
        self.database = database ?? connection.database
        
        let version = connection.serverVersion ?? "unknown"
        history = "Postgres Console (Echo), server \(version)\n"
        history += "This is Echo's managed PostgreSQL console powered by the app session.\n"
        history += "Native psql is a separate feature and is not wired into this build yet.\n\n"
        if self.database != connection.database {
            history += "Note: this tab is using the active PostgreSQL session for \(connection.database).\n"
            history += "Directly switching the connection database from this console is not implemented yet.\n\n"
        }
        prompt()
    }

    func prompt() {
        history += "\(database)=> "
    }
    
    func execute() {
        let command = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else {
            history += "\n"
            prompt()
            return
        }
        
        history += "\(input)\n"
        input = ""
        isExecuting = true
        
        Task {
            await performExecution(command)
            isExecuting = false
            prompt()
        }
    }
    
    private func ensureConnected() throws -> DatabaseSession {
        guard connection.databaseType == .postgresql else {
            throw DatabaseError.connectionFailed("PSQL is only available for PostgreSQL connections.")
        }
        return session
    }
    
    private func performExecution(_ sql: String) async {
        do {
            let session = try ensureConnected()
            let result = try await session.simpleQuery(sql)

            if !result.columns.isEmpty, !result.rows.isEmpty {
                history += ASCIIPlainTableFormatter.format(
                    columns: result.columns.map(\.name),
                    rows: result.rows
                )
            } else {
                history += "Command executed successfully.\n"
            }
        } catch {
            history += "ERROR: \(error.localizedDescription)\n"
        }
    }
    
    func estimatedMemoryUsageBytes() -> Int {
        return history.count * 2 // Roughly 2 bytes per char
    }
}
