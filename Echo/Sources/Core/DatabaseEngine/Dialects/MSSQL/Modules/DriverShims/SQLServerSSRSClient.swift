import SQLServerKit
import Foundation

/// Placeholder client for SQL Server Reporting Services (SSRS).
///
/// SSRS uses a REST API (ReportServer web service / SSRS REST API v2.0),
/// which is outside the scope of the native TDS protocol implemented by `sqlserver-nio`.
public final class SQLServerSSRSClient: @unchecked Sendable {
    private let client: SQLServerClient
    
    internal init(client: SQLServerClient) {
        self.client = client
    }
    
    public func fetchReports() async throws -> [String] {
        throw NSError(domain: "SQLServerSSRS", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "SSRS is not supported via TDS. It requires an HTTP client communicating with the SSRS REST API."
        ])
    }
}
