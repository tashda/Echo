import EchoSense
import Foundation

extension QueryEditorState {
    /// Round 28.7 (MS0): one note after each statement of a script that ran statement by
    /// statement; otherwise the run's one note.
    var runNotes: [QueryRunNote] {
        guard let runNote else { return [] }
        guard let entries = scriptEntries, entries.count > 1 else { return [runNote] }
        let notes = entries.compactMap(Self.note(for:))
        return notes.isEmpty ? [runNote] : notes
    }

    static func note(for entry: ScriptResultEntry) -> QueryRunNote? {
        guard let range = entry.editorRange else { return nil }
        switch entry.outcome {
        case .rows(_, let count):
            return QueryRunNote.success(range: range, rows: count, hasResults: true, duration: entry.duration)
        case .command(let tag):
            let text = "✓ \(tag)" + (entry.duration.map { " · \(QueryRunNote.formatted($0))" } ?? "")
            return QueryRunNote(range: range, text: text, detail: text, isError: false)
        case .failed(let message):
            return QueryRunNote.shortFailure(range: range, message: message)
        }
    }
}
