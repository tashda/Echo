import Foundation
import MySQLKit

extension MySQLBackupRestoreViewModel {
    /// The connection's TLS settings for `tool`, so a backup or restore is as protected as the
    /// connection. Keep the result until the tool has finished: client certificates converted for
    /// it are deleted with it. Nil when the session isn't a MySQL one.
    func toolTLS(for tool: URL) async throws -> MySQLToolTLS? {
        guard let mysql = session as? MySQLSession else { return nil }
        return try mysql.configuration.toolTLS(for: await processRunner.flavor(of: tool))
    }
}
