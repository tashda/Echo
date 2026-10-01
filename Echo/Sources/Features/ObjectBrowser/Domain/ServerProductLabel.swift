import Foundation

/// The product and release a server reports, the way people say it (round 16): "SQL Server
/// 2022" for "Microsoft SQL Server 16.0.4250.1", "PostgreSQL 18.3" as it is. The full build
/// stays in the tooltip.
nonisolated enum ServerProductLabel {
    /// SQL Server's major version to its release year.
    private static let sqlServerYears = ["17": "2025", "16": "2022", "15": "2019", "14": "2017", "13": "2016", "12": "2014", "11": "2012"]

    static func label(rawVersion: String?, databaseType: DatabaseType) -> String {
        guard let raw = rawVersion?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return databaseType == .microsoftSQL ? "SQL Server" : databaseType.displayName
        }
        guard databaseType == .microsoftSQL else { return raw }
        let build = raw.split(separator: " ").last.map(String.init) ?? ""
        let major = build.split(separator: ".").first.map(String.init) ?? ""
        guard build.first?.isNumber == true else { return raw.replacingOccurrences(of: "Microsoft SQL Server", with: "SQL Server") }
        return sqlServerYears[major].map { "SQL Server \($0)" } ?? "SQL Server \(build)"
    }
}
