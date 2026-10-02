import SwiftUI

/// Everything the form edits, so the editor can tell whether anything changed (round MC: Save is
/// dimmed until something did, Discard appears once it has). Passwords count separately, as a
/// typed password is never read back.
struct ConnectionEditorSnapshot: Equatable {
    var databaseType: DatabaseType
    var connectionName: String
    var host: String
    var port: Int
    var database: String
    var username: String
    var domain: String
    var authenticationMethod: DatabaseAuthenticationMethod
    var credentialSource: CredentialSource
    var identityID: UUID?
    var useTLS: Bool
    var trustServerCertificate: Bool
    var tlsMode: TLSMode
    var sslRootCertPath: String?
    var sslCertPath: String?
    var sslKeyPath: String?
    var mssqlEncryptionMode: MSSQLEncryptionMode
    var hostNameInCertificate: String
    var readOnlyIntent: Bool
    var allowLegacyTLS: Bool
    var connectionTimeout: TimeInterval
    var queryTimeLimit: TimeInterval?
    var confirmUnguardedWrites: Bool?
    var keepsQueryHistory: Bool
    var colorHex: String
    var railGlyph: ServerRailGlyph?
    var additionalHosts: [ConnectionHost]
    var targetSessionAttributes: PostgresConnectTo
    var loadBalanceHosts: Bool
    var kerberosServiceName: String

    /// The values the form starts from for a saved connection (or the blank model of a new one),
    /// read the same way `ConnectionEditorView.init` reads them.
    init(model: SavedConnection) {
        databaseType = model.databaseType
        connectionName = model.connectionName
        host = model.host
        port = model.port
        database = model.database
        username = model.username
        domain = model.domain
        authenticationMethod = model.authenticationMethod
        credentialSource = model.credentialSource
        identityID = model.identityID
        useTLS = model.useTLS
        trustServerCertificate = model.trustServerCertificate
        tlsMode = model.tlsMode
        sslRootCertPath = model.sslRootCertPath
        sslCertPath = model.sslCertPath
        sslKeyPath = model.sslKeyPath
        mssqlEncryptionMode = model.mssqlEncryptionMode
        hostNameInCertificate = model.hostNameInCertificate ?? ""
        readOnlyIntent = model.readOnlyIntent
        allowLegacyTLS = model.allowLegacyTLS
        connectionTimeout = model.connectionTimeout
        queryTimeLimit = model.queryTimeLimit
        confirmUnguardedWrites = model.confirmUnguardedWrites
        keepsQueryHistory = model.keepsQueryHistory
        colorHex = model.colorHex.isEmpty ? ServerColorPalette.defaultColor.lightHex : model.colorHex
        railGlyph = model.railGlyph
        additionalHosts = model.additionalHosts
        targetSessionAttributes = model.targetSessionAttributes
        loadBalanceHosts = model.loadBalanceHosts
        kerberosServiceName = model.kerberosServiceName ?? ""
    }
}

extension ConnectionEditorView {
    /// The form's current values.
    var currentSnapshot: ConnectionEditorSnapshot {
        var snapshot = initialSnapshot
        snapshot.databaseType = selectedDatabaseType
        snapshot.connectionName = connectionName
        snapshot.host = host
        snapshot.port = port
        snapshot.database = database
        snapshot.username = username
        snapshot.domain = domain
        snapshot.authenticationMethod = authenticationMethod
        snapshot.credentialSource = credentialSource
        snapshot.identityID = identityID
        snapshot.useTLS = useTLS
        snapshot.trustServerCertificate = trustServerCertificate
        snapshot.tlsMode = tlsMode
        snapshot.sslRootCertPath = sslRootCertPath
        snapshot.sslCertPath = sslCertPath
        snapshot.sslKeyPath = sslKeyPath
        snapshot.mssqlEncryptionMode = mssqlEncryptionMode
        snapshot.hostNameInCertificate = hostNameInCertificate
        snapshot.readOnlyIntent = readOnlyIntent
        snapshot.allowLegacyTLS = allowLegacyTLS
        snapshot.connectionTimeout = connectionTimeout
        snapshot.queryTimeLimit = queryTimeLimit
        snapshot.confirmUnguardedWrites = confirmUnguardedWrites
        snapshot.keepsQueryHistory = keepsQueryHistory
        snapshot.colorHex = colorHex
        snapshot.railGlyph = railGlyph
        snapshot.additionalHosts = additionalHosts
        snapshot.targetSessionAttributes = targetSessionAttributes
        snapshot.loadBalanceHosts = loadBalanceHosts
        snapshot.kerberosServiceName = kerberosServiceName
        return snapshot
    }

    /// Whether the form differs from what was saved (or from a blank new connection).
    var hasChanges: Bool {
        currentSnapshot != initialSnapshot || passwordDirty || keyPasswordDirty
    }
}
