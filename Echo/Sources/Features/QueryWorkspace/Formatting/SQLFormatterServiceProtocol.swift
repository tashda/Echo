import Foundation

protocol SQLFormatterServiceProtocol {
    func format(sql: String, dialect: SQLFormatterService.Dialect) async throws -> String
}
