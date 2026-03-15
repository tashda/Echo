import Foundation

protocol SQLFormatterProtocol {
    func format(sql: String, dialect: SQLFormatter.Dialect) async throws -> String
}
