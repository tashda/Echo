import Foundation

enum SQLEditorRegex {
    static let doubleQuotedStringPattern = #""(?:""|[^"])*""#
    static let doubleQuotedStringRegex = try! NSRegularExpression(
        pattern: doubleQuotedStringPattern,
        options: []
    )
}
