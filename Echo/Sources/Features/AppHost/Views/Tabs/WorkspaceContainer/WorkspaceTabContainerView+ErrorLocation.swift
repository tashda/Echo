import EchoSense
import SwiftUI

/// After a failed run: every server message in Messages (round 22 AM1, with the SSMS header EM1
/// and the line as a link LL1), and the error marked in the editor (round 21 EM5, EH3, IF1 and
/// RN1; round 22 ED1).
extension WorkspaceTabContainerView {
    /// AM1: what the server sent before and with the error, in order (PRINT output included).
    @MainActor
    func presentServerMessages(of error: any Error, sentSQL: String, state: QueryEditorState) {
        let editorText = state.sql
        let runRange = state.lastRunRange
        state.messageLineMapper = { line in
            QueryErrorMarker.editorLine(forSentLine: line, sentSQL: sentSQL, editorText: editorText, runRange: runRange)
        }
        for message in SQLServerFailure.serverMessages(of: error) {
            state.appendServerMessage(message)
        }
    }

    @MainActor
    func presentErrorLocation(of error: any Error, sentSQL: String, tab: WorkspaceTab, state: QueryEditorState) {
        state.errorMark = QueryErrorMarker.mark(
            for: error,
            sentSQL: sentSQL,
            editorText: state.sql,
            runRange: state.lastRunRange,
            columnCandidates: errorColumnCandidates(for: sentSQL, tab: tab)
        )
        // RN1: `! Error` at the statement unless Settings asks for the message.
        if !projectStore.globalSettings.editorErrorRunNoteShowsMessage {
            state.runNote = QueryRunNote.shortFailure(range: state.lastRunRange, message: error.localizedDescription)
        }
    }

    /// EH3 on SQL Server: the columns of the tables the SQL names, from the object browser's cache
    /// (nothing runs on the server).
    @MainActor
    func errorColumnCandidates(for sql: String, tab: WorkspaceTab) -> [String] {
        guard let structure = environmentState.sessionGroup.activeSessions
            .first(where: { $0.id == tab.connectionSessionID })?.databaseStructure else { return [] }
        let database = tab.activeDatabaseName ?? tab.connection.database
        let words = Set(sql.lowercased().split { !($0.isLetter || $0.isNumber || $0 == "_" || $0 == "#") }.map(String.init))
        var columns: [String] = []
        for db in structure.databases where database.isEmpty || db.name.caseInsensitiveCompare(database) == .orderedSame {
            for schema in db.schemas {
                for object in schema.objects where words.contains(object.name.lowercased()) {
                    columns.append(contentsOf: object.columns.map(\.name))
                }
            }
        }
        return columns
    }
}

/// The index of the batch that failed, set from the batch progress handler.
final class FailedBatchIndex: @unchecked Sendable {
    private let lock = NSLock()
    private var index: Int?

    func set(_ value: Int) { lock.withLock { if index == nil { index = value } } }
    var value: Int? { lock.withLock { index } }
}
