import SwiftUI

/// Round 14 · CN5: sample connections for editing inside Manage Connections.
enum LabEngine: String, CaseIterable, Identifiable {
    case postgres = "PostgreSQL"
    case sqlServer = "SQL Server"
    case mysql = "MySQL"
    case sqlite = "SQLite"

    var id: String { rawValue }

    var defaultPort: String {
        switch self {
        case .postgres: "5432"
        case .sqlServer: "1433"
        case .mysql: "3306"
        case .sqlite: ""
        }
    }

    var signInMethods: [String] {
        switch self {
        case .postgres: ["Password", "Certificate", "Kerberos"]
        case .sqlServer: ["SQL Server login", "Windows (Kerberos)", "Microsoft Entra ID"]
        case .mysql: ["Password", "Certificate"]
        case .sqlite: []
        }
    }

    var encryptionModes: [String] {
        self == .sqlServer ? ["Mandatory", "Optional", "Strict"] : ["Prefer TLS", "Require TLS", "Off"]
    }

    var monogram: String {
        switch self {
        case .postgres: "Pg"
        case .sqlServer: "SQL"
        case .mysql: "My"
        case .sqlite: "Lt"
        }
    }

    var badgeColor: Color {
        switch self {
        case .postgres: ColorTokens.Explorer.databaseInstance
        case .sqlServer: ColorTokens.Status.error
        case .mysql: ColorTokens.Explorer.views
        case .sqlite: ColorTokens.Explorer.integrationServices
        }
    }
}

struct LabConnection: Identifiable, Equatable {
    let id: String
    var name: String
    var engine: LabEngine
    var host: String
    var port: String = ""
    var database: String = ""
    var method: String
    var user: String
    var password: String = ""
    var remembersPassword = true
    var folder: String
    var colorIndex = 0
    var encryption: String
    var trustsCertificate = false
    var timeout: String = ""

    var address: String { port.isEmpty ? host : "\(host):\(port)" }

    static let colors: [Color] = [.blue, .green, .orange, .purple, .red, .gray]
    static let folders = ["Corporate", "Local", "Cloud"]

    static let samples: [LabConnection] = [
        LabConnection(id: "mssql", name: "Test MSSQL", engine: .sqlServer, host: "192.0.2.34", port: "14332", method: "SQL Server login", user: "sa", password: "••••••••", folder: "Local", colorIndex: 2, encryption: "Mandatory", trustsCertificate: true),
        LabConnection(id: "pg", name: "Local Postgres", engine: .postgres, host: "localhost", method: "Password", user: "postgres", folder: "Local", encryption: "Prefer TLS"),
        LabConnection(id: "prod", name: "Prod SQL", engine: .sqlServer, host: "prod-sql-01.contoso.com", database: "Sales", method: "Windows (Kerberos)", user: "CONTOSO\\echo", folder: "Corporate", colorIndex: 4, encryption: "Strict"),
        LabConnection(id: "shop", name: "Shop MySQL", engine: .mysql, host: "db.internal", method: "Password", user: "shop_ro", folder: "Cloud", colorIndex: 3, encryption: "Require TLS"),
    ]

    static func blank() -> LabConnection {
        LabConnection(id: UUID().uuidString, name: "", engine: .postgres, host: "", method: "Password", user: "", folder: "Local", encryption: "Prefer TLS")
    }
}

/// The engine's monogram tile, as in the connection list.
struct LabEngineBadge: View {
    let engine: LabEngine
    var size: CGFloat = SpacingTokens.md2

    var body: some View {
        Text(engine.monogram)
            .font((size > SpacingTokens.md2 ? TypographyTokens.detail : TypographyTokens.compact).weight(.heavy))
            .foregroundStyle(ColorTokens.DesignLabRound14.groupLabelTitle)
            .frame(width: size, height: size)
            .background(engine.badgeColor, in: .rect(cornerRadius: size > SpacingTokens.md2 ? SpacingTokens.xs : SpacingTokens.xxs1))
            .accessibilityLabel(engine.rawValue)
    }
}
