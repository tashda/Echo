import Foundation

extension SavedConnection {
    var objectBrowserCacheFingerprint: String {
        [
            "type=\(databaseType.rawValue)",
            "host=\(host.lowercased())",
            "port=\(port)",
            "database=\(database.lowercased())",
            "username=\(username.lowercased())",
            "auth=\(authenticationMethod.rawValue)",
            "domain=\(domain.lowercased())",
            "tls=\(useTLS)",
            "trust=\(trustServerCertificate)",
            "tlsMode=\(tlsMode.rawValue)",
            "mssqlEnc=\(mssqlEncryptionMode.rawValue)",
            "readonly=\(readOnlyIntent)"
        ]
        .joined(separator: "|")
    }
}
