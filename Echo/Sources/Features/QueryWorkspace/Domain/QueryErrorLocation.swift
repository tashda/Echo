import Foundation

/// Finds the line a database error points at (plan N4): SQL Server's "Line 3", Postgres's
/// "LINE 3:" and MySQL's "at line 3". Lines count from 1 in the batch that was sent.
nonisolated enum QueryErrorLocation {
    static func line(in message: String) -> Int? {
        guard let match = message.firstMatch(of: /(?i)\bline\s+(\d+)/),
              let line = Int(match.1), line > 0 else { return nil }
        return line
    }
}

/// Asks the editor to put the caret on a line and show it. A new request each time, so asking for
/// the same line twice works.
struct EditorLineRequest: Equatable {
    let line: Int
    let id = UUID()
}
