import Foundation

extension SavedConnection {
    var objectBrowserCacheFingerprint: String { cacheFingerprint(identity: nil) }

    func cacheFingerprint(identity: SavedIdentity?) -> String {
        let effective = usesIdentity ? identity : nil
        var fields = [
            "type": databaseType.rawValue, "host": databaseType == .sqlite ? host : host.lowercased(),
            "port": String(port), "database": database,
            "username": effective?.username ?? username,
            "auth": (effective?.authenticationMethod ?? authenticationMethod).rawValue,
            "domain": effective?.domain ?? domain, "identity": identityID?.uuidString ?? "",
            "source": credentialSource.rawValue, "tls": String(useTLS), "trust": String(trustServerCertificate),
            "tlsMode": tlsMode.rawValue, "mssqlEnc": mssqlEncryptionMode.rawValue,
            "readonly": String(readOnlyIntent), "legacyTLS": String(allowLegacyTLS),
            "certificateHost": hostNameInCertificate ?? "", "kerberos": kerberosServiceName ?? "",
            "target": targetSessionAttributes.rawValue, "balance": String(loadBalanceHosts)
        ]
        fields["hosts"] = additionalHosts.map { "\($0.host.lowercased()):\($0.port ?? port)" }.joined(separator: ",")
        for (name, path) in [("root", sslRootCertPath), ("cert", sslCertPath), ("key", sslKeyPath)] {
            let modified = path.flatMap { try? FileManager.default.attributesOfItem(atPath: $0)[.modificationDate] as? Date }
            fields[name] = "\(path ?? ""):\(modified?.timeIntervalSince1970 ?? 0)"
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(fields)).flatMap { String(data: $0, encoding: .utf8) } ?? "invalid"
    }

    /// Only used to recognize the owner's development cache before its one-time import.
    var legacyObjectBrowserCacheFingerprint: String {
        ["type=\(databaseType.rawValue)", "host=\(host.lowercased())", "port=\(port)",
         "database=\(database.lowercased())", "username=\(username.lowercased())",
         "auth=\(authenticationMethod.rawValue)", "domain=\(domain.lowercased())",
         "tls=\(useTLS)", "trust=\(trustServerCertificate)", "tlsMode=\(tlsMode.rawValue)",
         "mssqlEnc=\(mssqlEncryptionMode.rawValue)", "readonly=\(readOnlyIntent)"].joined(separator: "|")
    }
}
