import Foundation
import SwiftUI

@MainActor @Observable
final class PSQLTabViewModel: Identifiable {
    static let maxRenderedRows = 500
    static let maxTranscriptCharacters = 256_000
    static let transcriptTrimTarget = 192_000

    let id = UUID()
    let connection: SavedConnection
    internal var session: DatabaseSession
    @ObservationIgnored internal let sessionFactory: @Sendable (String) async throws -> DatabaseSession
    @ObservationIgnored var onActiveDatabaseChanged: ((String) -> Void)?
    var activeDatabase: String

    var history: String = ""
    var input: String = ""
    var isExecuting: Bool = false
    @ObservationIgnored internal var expandedDisplayEnabled = false
    @ObservationIgnored private var commandHistory: [String] = []
    @ObservationIgnored private var historyIndex: Int?
    @ObservationIgnored private var historyDraft: String = ""

    init(
        connection: SavedConnection,
        session: DatabaseSession,
        database: String? = nil,
        sessionFactory: @escaping @Sendable (String) async throws -> DatabaseSession
    ) {
        self.connection = connection
        self.session = session
        self.sessionFactory = sessionFactory
        let requestedDatabase = database?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackDatabase = connection.database.trimmingCharacters(in: .whitespacesAndNewlines)
        if let db = requestedDatabase, !db.isEmpty {
            self.activeDatabase = db
        } else {
            self.activeDatabase = fallbackDatabase.isEmpty ? "postgres" : fallbackDatabase
        }
        
        let version = connection.serverVersion ?? "unknown"
        history = "Postgres Console (Echo), server \(version)\n"
        history += "This is Echo's managed PostgreSQL console powered by a dedicated connection.\n"
        history += "Native psql is a separate feature and is not wired into this build yet.\n\n"
        prompt()
        Task {
            await resolveActiveDatabase()
        }
    }

    func prompt() {
        appendToHistory("\(activeDatabase)=> ")
    }
    
    func execute() {
        let command = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else {
            appendToHistory("\n")
            prompt()
            return
        }

        if commandHistory.last != command {
            commandHistory.append(command)
        }
        historyIndex = nil
        historyDraft = ""
        
        appendToHistory("\(input)\n")
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
        if sql.hasPrefix("\\") {
            await performMetaCommand(sql)
            return
        }

        do {
            let session = try ensureConnected()
            let result = try await session.simpleQuery(sql)

            if !result.columns.isEmpty, !result.rows.isEmpty {
                appendToHistory(renderResult(result))
            } else {
                appendToHistory("Command executed successfully.\n")
            }
        } catch {
            appendToHistory("ERROR: \(error.localizedDescription)\n")
        }
    }
    
    func estimatedMemoryUsageBytes() -> Int {
        return history.count * 2 // Roughly 2 bytes per char
    }

    func close() async {
        await session.close()
    }

    func showPreviousCommand() {
        guard !commandHistory.isEmpty else { return }
        if historyIndex == nil {
            historyDraft = input
            historyIndex = commandHistory.count - 1
        } else if let historyIndex, historyIndex > 0 {
            self.historyIndex = historyIndex - 1
        }

        if let historyIndex {
            input = commandHistory[historyIndex]
        }
    }

    func showNextCommand() {
        guard let historyIndex else { return }
        if historyIndex < commandHistory.count - 1 {
            let newIndex = historyIndex + 1
            self.historyIndex = newIndex
            input = commandHistory[newIndex]
        } else {
            self.historyIndex = nil
            input = historyDraft
        }
    }

    func resolveActiveDatabase() async {
        guard let result = try? await session.simpleQuery("SELECT current_database() AS current_database"),
              let firstRow = result.rows.first,
              let rawValue = firstRow.first ?? nil else {
            return
        }

        let resolved = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !resolved.isEmpty else { return }

        let previousDatabase = activeDatabase
        activeDatabase = resolved

        if previousDatabase != resolved {
            if history.hasSuffix("\(previousDatabase)=> ") {
                history.removeLast("\(previousDatabase)=> ".count)
            }
            onActiveDatabaseChanged?(resolved)
            prompt()
        }
    }

}

enum ExpandedPlainFormatter {
    static func format(columns: [String], rows: [[String?]], nullDisplay: String = "") -> String {
        guard !columns.isEmpty else { return "" }
        var output = ""

        for (rowIndex, row) in rows.enumerated() {
            output += "-[ RECORD \(rowIndex + 1) ]-\n"
            for (columnIndex, column) in columns.enumerated() {
                let value = columnIndex < row.count ? (row[columnIndex] ?? nullDisplay) : nullDisplay
                output += "\(column) | \(value)\n"
            }
        }

        output += "(\(rows.count) \(rows.count == 1 ? "row" : "rows"))\n"
        return output
    }
}
