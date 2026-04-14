import Foundation

struct AboutLink: Identifiable, Hashable {
    let title: String
    let subtitle: String
    let systemImage: String
    let url: URL

    var id: String { title }
}

struct AboutDependency: Identifiable, Hashable {
    let name: String
    let purpose: String
    let licenseName: String
    let repositoryURL: URL
    let licenseURL: URL?
    let notice: String

    var id: String { name }
}

enum AboutMetadata {
    static let homepageURL = URL(string: "https://echodb.dev")!

    static let quickLinks: [AboutLink] = [
        AboutLink(
            title: "Echo Homepage",
            subtitle: "Product site, release notes, and documentation",
            systemImage: "globe",
            url: homepageURL
        ),
        AboutLink(
            title: "postgres-wire",
            subtitle: "PostgreSQL driver used by Echo",
            systemImage: "shippingbox",
            url: URL(string: "https://github.com/tashda/postgres-wire")!
        ),
        AboutLink(
            title: "sqlserver-nio",
            subtitle: "SQL Server driver used by Echo",
            systemImage: "shippingbox",
            url: URL(string: "https://github.com/tashda/sqlserver-nio")!
        ),
        AboutLink(
            title: "mysql-wire",
            subtitle: "MySQL driver used by Echo",
            systemImage: "shippingbox",
            url: URL(string: "https://github.com/tashda/mysql-wire")!
        )
    ]

    static let dependencies: [AboutDependency] = [
        AboutDependency(
            name: "EchoSense",
            purpose: "Shared autocomplete and database metadata models",
            licenseName: "Repository notice not bundled",
            repositoryURL: URL(string: "https://github.com/tashda/EchoSense")!,
            licenseURL: nil,
            notice: "EchoSense is a first-party shared package used by Echo and the database drivers."
        ),
        AboutDependency(
            name: "postgres-wire",
            purpose: "PostgreSQL connectivity and metadata APIs",
            licenseName: "Apache 2.0",
            repositoryURL: URL(string: "https://github.com/tashda/postgres-wire")!,
            licenseURL: URL(string: "https://raw.githubusercontent.com/tashda/postgres-wire/dev/LICENSE.txt"),
            notice: "Verified from the package license bundled in the local checkout."
        ),
        AboutDependency(
            name: "sqlserver-nio",
            purpose: "SQL Server connectivity and administrative APIs",
            licenseName: "MIT",
            repositoryURL: URL(string: "https://github.com/tashda/sqlserver-nio")!,
            licenseURL: URL(string: "https://raw.githubusercontent.com/tashda/sqlserver-nio/dev/LICENSE"),
            notice: "Verified from the package license bundled in the local checkout."
        ),
        AboutDependency(
            name: "mysql-wire",
            purpose: "MySQL connectivity and metadata APIs",
            licenseName: "Repository notice not bundled",
            repositoryURL: URL(string: "https://github.com/tashda/mysql-wire")!,
            licenseURL: nil,
            notice: "Echo uses this first-party package for MySQL support. The current repository checkout does not include a separate license file."
        ),
        AboutDependency(
            name: "Sparkle",
            purpose: "Secure automatic updates",
            licenseName: "MIT-style with bundled external notices",
            repositoryURL: URL(string: "https://github.com/sparkle-project/Sparkle")!,
            licenseURL: URL(string: "https://raw.githubusercontent.com/sparkle-project/Sparkle/2.x/LICENSE"),
            notice: "Sparkle includes its own upstream notice plus additional third-party notices in the same license file."
        ),
        AboutDependency(
            name: "Supabase Swift",
            purpose: "Authentication and backend integration",
            licenseName: "MIT",
            repositoryURL: URL(string: "https://github.com/supabase/supabase-swift")!,
            licenseURL: URL(string: "https://raw.githubusercontent.com/supabase/supabase-swift/main/LICENSE"),
            notice: "Verified from the package license bundled in the local checkout."
        ),
        AboutDependency(
            name: "SQLiteNIO",
            purpose: "SQLite client support",
            licenseName: "MIT",
            repositoryURL: URL(string: "https://github.com/vapor/sqlite-nio")!,
            licenseURL: URL(string: "https://raw.githubusercontent.com/vapor/sqlite-nio/main/LICENSE"),
            notice: "Verified from the package license bundled in the local checkout."
        ),
        AboutDependency(
            name: "MySQLNIO",
            purpose: "Low-level MySQL protocol support",
            licenseName: "MIT",
            repositoryURL: URL(string: "https://github.com/vapor/mysql-nio")!,
            licenseURL: URL(string: "https://raw.githubusercontent.com/vapor/mysql-nio/main/LICENSE"),
            notice: "Verified from the package license bundled in the local checkout."
        ),
        AboutDependency(
            name: "PostgresNIO",
            purpose: "Low-level PostgreSQL protocol support",
            licenseName: "MIT",
            repositoryURL: URL(string: "https://github.com/vapor/postgres-nio")!,
            licenseURL: URL(string: "https://raw.githubusercontent.com/vapor/postgres-nio/main/LICENSE"),
            notice: "Verified from the package license bundled in the local checkout."
        ),
        AboutDependency(
            name: "Swift Crypto",
            purpose: "Cryptographic primitives used by the app and drivers",
            licenseName: "Apache 2.0",
            repositoryURL: URL(string: "https://github.com/apple/swift-crypto")!,
            licenseURL: URL(string: "https://raw.githubusercontent.com/apple/swift-crypto/main/LICENSE.txt"),
            notice: "Verified from the package license bundled in the local checkout."
        )
    ]
}
