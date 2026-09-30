import Foundation

/// Reads a pasted connection URL or ADO.NET-style connection string into connection fields
/// (Design/05-components › Connections: pasting a URL fills the form).
///
/// Understands `postgres://`, `postgresql://`, `mysql://`, `mariadb://`, `sqlserver://`,
/// `mssql://`, `sqlite://` and `file://` URLs (with or without a `jdbc:` prefix, credentials and a
/// query string), and `Server=…;Database=…;User Id=…;Password=…` strings for SQL Server.
nonisolated enum ConnectionStringParser {
    struct Result: Equatable, Sendable {
        var databaseType: DatabaseType
        var host: String
        var port: Int?
        var database: String?
        var username: String?
        var password: String?
        /// PostgreSQL: the servers after the first (postgres://db1,db2:5433/app), and the
        /// target_session_attrs, load_balance_hosts and krbsrvname parameters (round 23, PU1).
        var additionalHosts: [ConnectionHost] = []
        var targetSessionAttributes: PostgresConnectTo?
        var loadBalanceHosts = false
        var kerberosServiceName: String?
    }

    static func parse(_ text: String) -> Result? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.contains("://") { return parseURL(trimmed) }
        if trimmed.contains("="), trimmed.contains(";") || trimmed.lowercased().hasPrefix("server=") || trimmed.lowercased().hasPrefix("data source=") {
            return parseKeyValue(trimmed)
        }
        return nil
    }

    // MARK: URLs

    private static func parseURL(_ text: String) -> Result? {
        var value = text
        if value.lowercased().hasPrefix("jdbc:") { value.removeFirst(5) }
        guard let schemeEnd = value.range(of: "://") else { return nil }
        let scheme = value[..<schemeEnd.lowerBound].lowercased()
        guard let type = databaseType(forScheme: scheme) else { return nil }

        if type == .sqlite {
            let path = String(value[schemeEnd.upperBound...])
            return path.isEmpty ? nil : Result(databaseType: .sqlite, host: path.removingPercentEncoding ?? path)
        }
        if type == .microsoftSQL, !value.contains("@") || value.contains(";") {
            return parseSQLServerURL(String(value[schemeEnd.upperBound...]))
        }

        var rest = String(value[schemeEnd.upperBound...])
        var additionalHosts: [ConnectionHost] = []
        if type == .postgresql {
            (rest, additionalHosts) = splitHosts(rest)
        }
        guard let components = URLComponents(string: "\(scheme == "mssql" ? "sqlserver" : scheme)://\(rest)"),
              let host = components.host, !host.isEmpty else { return nil }
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let queryDatabase = components.queryItems?.first { ["database", "databasename", "dbname"].contains($0.name.lowercased()) }?.value
        var result = Result(
            databaseType: type,
            host: host,
            port: components.port,
            database: path.isEmpty ? queryDatabase : path.removingPercentEncoding,
            username: components.user?.removingPercentEncoding,
            password: components.password?.removingPercentEncoding
        )
        if type == .postgresql {
            let query = Dictionary((components.queryItems ?? []).map { ($0.name.lowercased(), $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
            result.additionalHosts = additionalHosts
            result.targetSessionAttributes = query["target_session_attrs"].flatMap(PostgresConnectTo.init(rawValue:))
            result.loadBalanceHosts = query["load_balance_hosts"] == "random"
            result.kerberosServiceName = query["krbsrvname"].flatMap { $0.isEmpty ? nil : $0 }
        }
        return result
    }

    /// `user@db1:5432,db2:5433/app` → `user@db1:5432/app` and the other servers, as libpq reads them.
    private static func splitHosts(_ rest: String) -> (String, [ConnectionHost]) {
        let authorityEnd = rest.firstIndex { $0 == "/" || $0 == "?" } ?? rest.endIndex
        let authority = rest[..<authorityEnd]
        let userEnd = authority.lastIndex(of: "@").map { authority.index(after: $0) } ?? authority.startIndex
        let hostList = authority[userEnd...]
        guard hostList.contains(",") else { return (rest, []) }
        let entries = hostList.split(separator: ",", omittingEmptySubsequences: true).map(String.init)
        guard let first = entries.first else { return (rest, []) }
        let others = entries.dropFirst().map { entry -> ConnectionHost in
            // "[::1]:5433", "db2:5433", "db2"
            if let colon = entry.lastIndex(of: ":"), !entry.hasSuffix("]"), let port = Int(entry[entry.index(after: colon)...]) {
                return ConnectionHost(host: String(entry[..<colon]).trimmingCharacters(in: CharacterSet(charactersIn: "[]")), port: port)
            }
            return ConnectionHost(host: entry.trimmingCharacters(in: CharacterSet(charactersIn: "[]")), port: nil)
        }
        return (String(authority[..<userEnd]) + first + String(rest[authorityEnd...]), others)
    }

    /// `sqlserver://host[\instance][:port];databaseName=db;user=u;password=p`
    private static func parseSQLServerURL(_ rest: String) -> Result? {
        let parts = rest.split(separator: ";", omittingEmptySubsequences: true).map(String.init)
        guard let address = parts.first, !address.isEmpty else { return nil }
        var result = Result(databaseType: .microsoftSQL, host: address)
        if let colon = address.lastIndex(of: ":"), let port = Int(address[address.index(after: colon)...]) {
            result.host = String(address[..<colon])
            result.port = port
        }
        apply(pairs(parts.dropFirst()), to: &result)
        return result.host.isEmpty ? nil : result
    }

    private static func databaseType(forScheme scheme: String) -> DatabaseType? {
        switch scheme {
        case "postgres", "postgresql": .postgresql
        case "mysql", "mariadb": .mysql
        case "sqlserver", "mssql": .microsoftSQL
        case "sqlite", "file": .sqlite
        default: nil
        }
    }

    // MARK: Key-value strings (SQL Server)

    private static func parseKeyValue(_ text: String) -> Result? {
        let parts = text.split(separator: ";", omittingEmptySubsequences: true).map(String.init)
        let values = pairs(parts)
        guard let server = values["server"] ?? values["data source"] ?? values["address"] ?? values["addr"] ?? values["host"] else { return nil }
        var address = server.trimmingCharacters(in: .whitespaces)
        if address.lowercased().hasPrefix("tcp:") { address.removeFirst(4) }
        var result = Result(databaseType: .microsoftSQL, host: address)
        if let comma = address.lastIndex(of: ","), let port = Int(address[address.index(after: comma)...].trimmingCharacters(in: .whitespaces)) {
            result.host = String(address[..<comma])
            result.port = port
        }
        apply(values, to: &result)
        return result.host.isEmpty ? nil : result
    }

    private static func pairs<S: Sequence>(_ parts: S) -> [String: String] where S.Element == String {
        var values: [String: String] = [:]
        for part in parts {
            guard let equals = part.firstIndex(of: "=") else { continue }
            let key = part[..<equals].trimmingCharacters(in: .whitespaces).lowercased()
            let value = part[part.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            values[key] = value
        }
        return values
    }

    private static func apply(_ values: [String: String], to result: inout Result) {
        if let database = values["database"] ?? values["databasename"] ?? values["initial catalog"] { result.database = database }
        if let user = values["user id"] ?? values["uid"] ?? values["user"] ?? values["username"] { result.username = user }
        if let password = values["password"] ?? values["pwd"] { result.password = password }
    }
}
