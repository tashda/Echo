import Foundation

nonisolated struct MySQLServerConfigurationCandidate: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let path: String
    let source: String
}

nonisolated enum MySQLServerConfigurationLocator {
    static func candidates(
        host: String,
        baseDirectory: String?,
        dataDirectory: String?
    ) -> [MySQLServerConfigurationCandidate] {
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let canUseLocalPaths = normalizedHost.isEmpty ||
            normalizedHost == "localhost" ||
            normalizedHost == "127.0.0.1" ||
            normalizedHost == "::1"

        var seenPaths = Set<String>()
        var results: [MySQLServerConfigurationCandidate] = []

        func append(_ title: String, path: String?, source: String) {
            guard let path, !path.isEmpty else { return }
            let expanded = NSString(string: path).expandingTildeInPath
            guard seenPaths.insert(expanded).inserted else { return }
            results.append(
                MySQLServerConfigurationCandidate(
                    id: expanded,
                    title: title,
                    path: expanded,
                    source: source
                )
            )
        }

        if canUseLocalPaths {
            append("Primary Config", path: "/etc/my.cnf", source: "Standard location")
            append("MySQL Config", path: "/etc/mysql/my.cnf", source: "Standard location")
            append("Homebrew Config", path: "/opt/homebrew/etc/my.cnf", source: "Homebrew")
            append("Intel Homebrew Config", path: "/usr/local/etc/my.cnf", source: "Homebrew")
        }

        if let baseDirectory {
            append("Base Directory Config", path: "\(baseDirectory)/my.cnf", source: "basedir")
            append("Support Files Config", path: "\(baseDirectory)/support-files/my-default.cnf", source: "basedir")
        }

        if let dataDirectory {
            let directoryURL = URL(fileURLWithPath: dataDirectory)
            append("Sibling Config", path: directoryURL.deletingLastPathComponent().appendingPathComponent("my.cnf").path, source: "datadir")
        }

        return results
    }
}
