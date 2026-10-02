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
            title: "echo-postgres",
            subtitle: "PostgreSQL driver used by Echo",
            systemImage: "shippingbox",
            url: URL(string: "https://github.com/tashda/echo-postgres")!
        ),
        AboutLink(
            title: "echo-sqlserver",
            subtitle: "SQL Server driver used by Echo",
            systemImage: "shippingbox",
            url: URL(string: "https://github.com/tashda/echo-sqlserver")!
        ),
        AboutLink(
            title: "echo-mysql",
            subtitle: "MySQL driver used by Echo",
            systemImage: "shippingbox",
            url: URL(string: "https://github.com/tashda/echo-mysql")!
        )
    ]

    static let dependencies: [AboutDependency] = [
        AboutDependency(
            name: "EchoSense",
            purpose: "Shared autocomplete and database metadata models",
            licenseName: "Repository notice not bundled",
            repositoryURL: URL(string: "https://github.com/tashda/echo-sense")!,
            licenseURL: nil,
            notice: "EchoSense is a first-party shared package used by Echo and the database drivers."
        ),
        AboutDependency(
            name: "echo-postgres",
            purpose: "PostgreSQL connectivity and metadata APIs",
            licenseName: "Apache 2.0",
            repositoryURL: URL(string: "https://github.com/tashda/echo-postgres")!,
            licenseURL: URL(string: "https://raw.githubusercontent.com/tashda/echo-postgres/dev/LICENSE.txt"),
            notice: "Verified from the package license bundled in the local checkout."
        ),
        AboutDependency(
            name: "echo-sqlserver",
            purpose: "SQL Server connectivity and administrative APIs",
            licenseName: "MIT",
            repositoryURL: URL(string: "https://github.com/tashda/echo-sqlserver")!,
            licenseURL: URL(string: "https://raw.githubusercontent.com/tashda/echo-sqlserver/dev/LICENSE"),
            notice: "Verified from the package license bundled in the local checkout."
        ),
        AboutDependency(
            name: "echo-mysql",
            purpose: "MySQL connectivity and metadata APIs",
            licenseName: "Repository notice not bundled",
            repositoryURL: URL(string: "https://github.com/tashda/echo-mysql")!,
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
            name: "PostgreSQL (libpq and tools)",
            purpose: "PostgreSQL connections, and pg_dump, pg_restore, pg_dumpall and psql for backups",
            licenseName: "PostgreSQL License",
            repositoryURL: URL(string: "https://www.postgresql.org")!,
            licenseURL: URL(string: "https://www.postgresql.org/about/licence/"),
            notice: "PostgreSQL 18.6, built by echo-libraries."
        ),
        AboutDependency(
            name: "MariaDB Connector/C",
            purpose: "MySQL and MariaDB connections",
            licenseName: "LGPL 2.1 or later",
            repositoryURL: URL(string: "https://github.com/mariadb-corporation/mariadb-connector-c")!,
            licenseURL: URL(string: "https://raw.githubusercontent.com/mariadb-corporation/mariadb-connector-c/3.4/COPYING.LIB"),
            notice: "Version 3.4.11, unmodified and dynamically linked as its own framework (EchoMariaDB.framework), which you may replace with another build of the same version. Source: https://archive.mariadb.org/connector-c-3.4.11/"
        ),
        AboutDependency(
            name: "OpenSSL",
            purpose: "TLS for PostgreSQL, MySQL and MariaDB connections",
            licenseName: "Apache 2.0",
            repositoryURL: URL(string: "https://www.openssl.org")!,
            licenseURL: URL(string: "https://www.openssl.org/source/license.html"),
            notice: "OpenSSL 3.5.9, built by echo-libraries."
        ),
        AboutDependency(
            name: "zstd and lz4",
            purpose: "Compression for PostgreSQL backups and connections",
            licenseName: "BSD",
            repositoryURL: URL(string: "https://github.com/facebook/zstd")!,
            licenseURL: URL(string: "https://raw.githubusercontent.com/facebook/zstd/dev/LICENSE"),
            notice: "zstd 1.5.7 (BSD-3-Clause) and lz4 1.10.0 (BSD-2-Clause), built by echo-libraries."
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
