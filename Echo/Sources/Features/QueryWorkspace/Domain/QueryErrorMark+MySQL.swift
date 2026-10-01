import Foundation
import MySQLKit

/// MySQL and MariaDB name the line of an error and the text it starts at ("… near 'FORM t' at
/// line 2"); the mark goes there, as for PostgreSQL and SQL Server (round C4 reuses round 21; #39).
extension QueryErrorMarker {
    struct MySQLPointer: Equatable {
        let message: String
        /// 1-based line in the statement.
        let line: Int
        /// The text the server stopped at.
        let near: String?

        init?(message: String) {
            guard let lineMarker = message.range(of: " at line ", options: .backwards),
                  let line = Int(message[lineMarker.upperBound...].prefix { $0.isNumber }) else { return nil }
            self.message = message
            self.line = line
            if let start = message.range(of: "near '"), start.upperBound <= lineMarker.lowerBound {
                let text = message[start.upperBound..<lineMarker.lowerBound]
                near = text.hasSuffix("'") ? String(text.dropLast()) : String(text)
            } else {
                near = nil
            }
        }

        init?(_ error: any Error) {
            var candidate: any Error = error
            if let database = error as? DatabaseError, case .queryError(_, let underlying?) = database {
                candidate = underlying
            }
            guard let mysql = candidate as? MySQLError else { return nil }
            self.init(message: mysql.message)
        }
    }

    static func mysqlMark(_ pointer: MySQLPointer, in located: Located) -> QueryErrorMark? {
        let lineInTrimmed = pointer.line - located.leadingNewlines
        guard lineInTrimmed >= 1, let line = lineRange(lineInTrimmed, in: located.trimmed) else { return nil }
        var range = trimmedLine(line, in: located.trimmed)
        // Narrow to the first word the server stopped at.
        if let near = pointer.near, let word = near.split(whereSeparator: \.isWhitespace).first {
            let lineText = located.trimmed.substring(with: line) as NSString
            let found = lineText.range(of: String(word))
            if found.location != NSNotFound {
                range = NSRange(location: line.location + found.location, length: found.length)
            }
        }
        return make(range: NSRange(location: located.base + range.location, length: range.length), in: located,
                    message: pointer.message, detail: nil, fix: nil)
    }
}
