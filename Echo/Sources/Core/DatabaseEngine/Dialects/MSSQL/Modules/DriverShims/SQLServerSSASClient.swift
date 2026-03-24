import SQLServerKit
import Foundation

/// Placeholder client for SQL Server Analysis Services (SSAS).
///
/// SSAS uses the XMLA protocol over HTTP/TCP, which is outside the scope of
/// the native TDS protocol implemented by `sqlserver-nio`. Future implementations
/// would require a dedicated XMLA client library.
public final class SQLServerSSASClient: @unchecked Sendable {
    private let client: SQLServerClient
    
    internal init(client: SQLServerClient) {
        self.client = client
    }
    
    public func fetchModels() async throws -> [String] {
        throw NSError(domain: "SQLServerSSAS", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "SSAS is not supported via TDS. It requires an XMLA client."
        ])
    }
}
